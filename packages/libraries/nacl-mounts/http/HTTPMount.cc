/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include "HTTPMount.h"
#include "HTTPNode.h"
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

HTTPMount::HTTPMount(MainThreadRunner *runner, std::string base_url) {
  runner_ = runner;
  base_url_ = base_url;
  // leave slot 0 open
  slots_.Alloc();
  // Create a root directory
  AddFile("/");
  int slot = slots_.Alloc();
  HTTPNode *node = slots_.At(slot);
  node->slot = slot;
  node->path = "/";
}

bool HTTPMount::IsDir(const std::string& path) {
  if (path == "/") {
    return true;
  }
  std::string pathslash = path + "/";
  std::set<std::string>::iterator it;
  for (it = files_.begin(); it != files_.end(); ++it) {
    size_t pos = it->find(pathslash);
    if (pos == 0) {
      return true;
    }
  }
  return false;
}

int HTTPMount::Creat(const std::string& path, mode_t mode, struct stat* buf) {
  HTTPNode *child;

  Path p(path);
  std::string fp = p.FormulatePath();
  if (files_.find(fp) == files_.end() && !IsDir(fp)) {
    errno = ENOENT;
    return -1;
  }

  // Create it.
  int slot = slots_.Alloc();
  child = slots_.At(slot);
  child->slot = slot;
  child->path = fp;

  assert(buf);
  return Stat(slot, buf);
}

int HTTPMount::GetNode(const std::string& path, struct stat* buf) {
  HTTPNode *node = NULL;
  for (int slot = 0; node = slots_.At(slot); ++slot) {
    if (node->path == path) {
      return Stat(slot, buf);
    }
  }
  return -1;
}

int HTTPMount::Stat(ino_t slot, struct stat *buf) {
  memset(buf, 0, sizeof(struct stat));
  HTTPNode* node = slots_.At(slot);
  if (node == NULL) {
    errno = ENOENT;
    return -1;
  }
  buf->st_ino = (ino_t)slot;
  if (IsDir(node->path)) {
    buf->st_mode = S_IFDIR | 0777;
  } else {
    UrlLoaderJob *job = new UrlLoaderJob;
    std::string url = base_url_ + node->path;
    job->set_url(url);
    job->set_method("GET");
    job->set_content_range(0, 0);
    UrlLoaderJob::Result result;
    job->set_result_dst(&result);
    int ret = runner_->RunJob(job);
    // Request must succeed and file must exist (code 206).
    if (ret || result.status_code != 206) {
      errno = ENOENT;
      return -1;
    }
    buf->st_mode = S_IFREG | 0777;
    buf->st_size = result.length;
  }
  buf->st_uid = 1001;
  buf->st_gid = 1002;
  buf->st_blksize = 1024;
  return 0;
}

int HTTPMount::Getdents(ino_t slot, off_t offset,
                        struct dirent *dir, unsigned int count) {
  HTTPNode* node = slots_.At(slot);
  if (node == NULL) {
    errno = ENOTDIR;
    return -1;
  }
  std::list<std::string> path_parts = Path(node->path).path();
  std::set<std::string> entries;
  std::string pathslash = node->path;
  if (pathslash != "/") {
    pathslash += "/";
  }
  for (std::set<std::string>::iterator it = files_.begin(); it != files_.end();
       ++it) {
    size_t pos = it->find(pathslash);
    if (pos == 0) {
      int len = path_parts.size();
      std::list<std::string> ipath_parts = Path(*it).path();
      std::list<std::string>::iterator i_it = ipath_parts.begin();
      assert (ipath_parts.size() > len);
      while (len > 0) {
        --len;
        ++i_it;
      }
      entries.insert(*i_it);
    }
  }

  // Now that we have the directory names, we can formulate the dirent structs.
  std::set<std::string>::iterator it = entries.begin();
  // Skip to the offset
  while (offset > 0 && it != entries.end()) {
    --offset;
    ++it;
  }

  int bytes_read = 0;
  for (; it != entries.end() &&
       bytes_read + sizeof(struct dirent) <= count; ++it) {
    memset(dir, 0, sizeof(struct dirent));
    // We want d_ino to be non-zero because readdir()
    // will return null if d_ino is zero.
    dir->d_ino = 0x60061E;
    dir->d_off = sizeof(struct dirent);
    dir->d_reclen = sizeof(struct dirent);
    strncpy(dir->d_name, it->c_str(), sizeof(dir->d_name));
    ++dir;
    bytes_read += sizeof(struct dirent);
  }
  return bytes_read;
}

ssize_t HTTPMount::Read(ino_t slot, off_t offset, void *buf, size_t count) {
  HTTPNode* node = slots_.At(slot);
  if (node == NULL) {
    errno = ENOENT;
    return -1;
  }

  UrlLoaderJob *job = new UrlLoaderJob;
  std::string url = base_url_ + node->path;
  job->set_url(url);
  job->set_method("GET");
  job->set_content_range(offset, count-1);
  UrlLoaderJob::Result result;
  job->set_result_dst(&result);
  std::vector<char> dst;
  job->set_dst(&dst);
  // TODO(arbenson): Make sure that UrlLoaderJob will error if more
  // bytes are read than are expected
  int ret = runner_->RunJob(job);
  // Request must succeed on partial content request (code 206).
  if (ret || result.status_code != 206) {
    errno = EIO;
    return -1;
  }
  if (count < result.length) result.length = count;
  memcpy(buf, &dst[0], result.length);
  return result.length;
}


void HTTPMount::AddFile(const std::string& file) {
  Path p(file);
  files_.insert(p.FormulatePath());
}
