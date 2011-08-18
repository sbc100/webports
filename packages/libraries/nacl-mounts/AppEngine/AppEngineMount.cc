/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <vector>
#include "../base/UrlLoaderJob.h"
#include "../util/Path.h"
#include "../util/SimpleAutoLock.h"
#include "AppEngineMount.h"
#include "AppEngineNode.h"

AppEngineMount::AppEngineMount(MainThreadRunner *runner,
                               const std::string& base_url) {
  if (pthread_mutex_init(&ae_lock_, NULL)) assert(0);
  runner_ = runner;
  base_url_ = base_url;
  slots_.Alloc();
  int slot = CreateNode("/", NULL);
  AppEngineNode *node = slots_.At(slot);
  node->set_is_dir(true);
}

int AppEngineMount::RemoteRead(const std::string& path,
                               std::vector<char> *data) {
  UrlLoaderJob *job = new UrlLoaderJob;
  job->set_method("POST");
  job->set_dst(data);
  job->AppendField("filename", path);
  job->set_url(base_url_ + "/read");
  return runner_->RunJob(job);
}

int AppEngineMount::CreateNode(const std::string& path,
                               std::vector<char> *data) {
  int slot = slots_.Alloc();
  AppEngineNode *node = slots_.At(slot);
  node->set_path(path);
  node->set_slot(slot);
  node->set_is_dir(false);
  node->IncrementUseCount();
  if (data) {
    node->set_data(*data);
  }
  path_map_[path] = slot;
  return slot;
}

int AppEngineMount::Creat(const std::string& path, mode_t mode,
                          struct stat *buf) {
  Path p("/" + path);
  std::string abs_path = p.FormulatePath();
  SimpleAutoLock lock(&ae_lock_);

  // First, check if the path is in the path map.
  if (path_map_.count(abs_path) != 0) {
    errno = EEXIST;
    return -1;
  }

  // Second, check if the path is on GAE
  std::vector<char> data;
  if (RemoteRead(abs_path, &data)) {
    errno = EIO;
    return -1;
  }
  if (data.size() > 0 && data[data.size()-1] == '1') {
    errno = EEXIST;
    return -1;
  }
  assert(buf);
  return Stat(CreateNode(abs_path, NULL), buf);
}

int AppEngineMount::GetNode(const std::string& path, struct stat *buf) {
  Path p("/" + path);
  std::string abs_path = p.FormulatePath();
  SimpleAutoLock lock(&ae_lock_);
  std::map<std::string, int>::iterator it = path_map_.find(abs_path);
  if (it != path_map_.end()) {
    return Stat(it->second, buf);
  }
  std::vector<char> data;
  if (RemoteRead(abs_path, &data)) {
    errno = EIO;
    return -1;
  }
  if (data.size() == 0 || data[data.size()-1] == '0') {
    return -1;
  }
  data.pop_back();

  assert(buf);
  return Stat(CreateNode(abs_path, &data), buf);
}

int AppEngineMount::Stat(ino_t slot, struct stat *buf) {
  AppEngineNode *node = slots_.At(slot);
  if (node == NULL) {
    errno = ENOENT;
    return -1;
  }

  memset(buf, 0, sizeof(struct stat));
  buf->st_ino = (ino_t)slot;
  if (node->is_dir() || IsDir(slot)) {
    buf->st_mode = S_IFDIR | 0777;
  } else {
    buf->st_mode = S_IFREG | 0777;
    buf->st_size = node->len();
  }
  buf->st_uid = 1001;
  buf->st_gid = 1002;
  buf->st_blksize = 1024;
  return 0;
}

void AppEngineMount::Ref(ino_t slot) {
  SimpleAutoLock lock(&ae_lock_);
  AppEngineNode *node = slots_.At(slot);
  if (node == NULL) {
    return;
  }
  node->IncrementUseCount();
}

void AppEngineMount::Unref(ino_t slot) {
  SimpleAutoLock lock(&ae_lock_);
  AppEngineNode *node = slots_.At(slot);
  if (node == NULL) {
    return;
  }
  if (node->is_dir()) {
    return;
  }
  node->DecrementUseCount();
  if (node->use_count() > 0) {
    return;
  }
  // Sync data to AppEngine
  Fsync(slot);
  // Remove from our list of nodes
  path_map_.erase(node->path());
  // Remove from slots
  slots_.Free(node->slot());
}

int AppEngineMount::Getdents(ino_t slot, off_t offset,
                             struct dirent *dir, unsigned int count) {
  AppEngineNode *node = slots_.At(slot);
  if (node == NULL) {
    errno = ENOTDIR;
    return -1;
  }

  UrlLoaderJob *job = new UrlLoaderJob;
  job->set_method("POST");
  std::vector<char> dst;
  job->set_dst(&dst);
  job->AppendField("prefix", node->path());
  job->set_url(base_url_ + "/list");
  int ret = runner_->RunJob(job);
  if (ret) {
    return -1;
  }

  std::vector<std::string> entries;
  std::vector<char>::iterator ind = dst.begin();
  std::vector<char>::iterator next = dst.begin();
  while (ind != dst.end() && next != dst.end()) {
    if (*next == '\n' && ind != next) {
      if (*ind == '\n') {
        ++ind;
      }
      if (ind != next) {
        entries.push_back(std::string(ind, next));
      }
      ind = next;
    }
    ++next;
  }
  if (ind != next) {
    std::string last(ind, next-1);
    if (!last.empty()) {
      entries.push_back(last);
    }
  }

  // Now that we have the directory names, we can formulate the dirent structs.
  // We ignore the offset and just list everything.
  std::vector<std::string>::iterator it;
  int pos = 0;
  int bytes_read = 0;
  for (it = entries.begin(); it != entries.end() &&
       bytes_read + sizeof(struct dirent) <= count; ++it) {
    memset(dir, 0, sizeof(struct dirent));
    // We want d_ino to be non-zero because readdir()
    // will return null if d_ino is zero.
    dir->d_ino = 0x60061E;
    dir->d_off = sizeof(struct dirent);
    dir->d_reclen = sizeof(struct dirent);
    strncpy(dir->d_name, it->c_str(), sizeof(dir->d_name));
    ++dir;
    ++pos;
    bytes_read += sizeof(struct dirent);
  }
  return bytes_read;
}

ssize_t AppEngineMount::Read(ino_t slot, off_t offset, void *buf,
                             size_t count) {
  SimpleAutoLock lock(&ae_lock_);
  AppEngineNode *node = slots_.At(slot);
  if (node == NULL) {
    errno = ENOENT;
    return -1;
  }
  // Limit to the end of the file.
  size_t len = count;
  size_t node_len = node->len();
  if (len > node_len - offset) {
    len = node_len - offset;
  }

  // Do the read.
  char *data = node->data();
  if (data) {
    memcpy(buf, data + offset, len);
  } else {
    return 0;
  }
  return len;
}

ssize_t AppEngineMount::Write(ino_t slot, off_t offset, const void *buf,
                              size_t count) {
  SimpleAutoLock lock(&ae_lock_);
  AppEngineNode *node = slots_.At(slot);
  if (node == NULL) {
    errno = ENOENT;
    return -1;
  }
  // Write out the block.
  if (node->WriteData(offset, buf, count) == -1) {
    return -1;
  }
  return count;
}

int AppEngineMount::Fsync(ino_t slot) {
  SimpleAutoLock lock(&ae_lock_);
  AppEngineNode *node = slots_.At(slot);
  if (!node->is_dirty()) {
    return 0;
  }
  UrlLoaderJob *job = new UrlLoaderJob;
  job->set_method("POST");
  std::vector<char> dst;
  job->set_dst(&dst);
  job->AppendField("filename", node->path());
  job->AppendDataField("data", node->data(), node->len(), false);
  job->set_url(base_url_ + "/write");
  int ret = runner_->RunJob(job);
  if (ret || dst.size() == 0 || dst[dst.size()-1] != '1') {
    errno = EIO;
    return -1;
  }
  node->set_is_dirty(false);
  return 0;
}

int AppEngineMount::Unlink(const std::string& path) {
  SimpleAutoLock lock(&ae_lock_);
  Path p("/" + path);
  std::string abs_path = p.FormulatePath();
  // Remove from our list of nodes
  path_map_.erase(abs_path);
  UrlLoaderJob *job = new UrlLoaderJob;
  job->set_method("POST");
  std::vector<char> dst;
  job->set_dst(&dst);
  job->AppendField("filename", abs_path);
  job->set_url(base_url_ + "/remove");
  int ret = runner_->RunJob(job);
  if (ret || dst.size() == 0 || dst[dst.size()-1] != '1') {
    errno = EIO;
    return -1;
  }
  return 0;
}

int AppEngineMount::Mkdir(const std::string& path, mode_t mode,
                          struct stat *buf) {
  int ret = Creat(path, mode, buf);
  if (ret) {
    return ret;
  }
  AppEngineNode *node = slots_.At(buf->st_ino);
  node->set_is_dir(true);
  return 0;
}

bool AppEngineMount::IsDir(ino_t slot) {
  AppEngineNode *node = slots_.At(slot);
  if (!node) {
    return false;
  }

  struct dirent *dir = (struct dirent *)malloc(sizeof(struct dirent));
  int num_bytes = Getdents(slot, 0, dir, sizeof(struct dirent));

  if (num_bytes > 0) {
    // Cache this result in the node.  At this point, we consider the node
    // to be a directory for the rest of run-time
    node->set_is_dir(true);
    return true;
  }
  return false;
}
