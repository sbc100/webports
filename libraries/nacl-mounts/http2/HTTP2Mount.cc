/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include "HTTP2Mount.h"
#include "HTTP2Node.h"
#include "HTTP2OpenJob.h"
#include "HTTP2ReadJob.h"
#include "../util/DebugPrint.h"
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

HTTP2Mount::HTTP2Mount(MainThreadRunner *runner, std::string base_url) {
  runner_ = runner;
  base_url_ = base_url;
  // leave slot 0 open
  slots_.Alloc();
  AddDir("/");
}

int HTTP2Mount::GetSlot(const std::string& path) {
  std::string p = Path(path).FormulatePath();
  HTTP2Node *node = NULL;
  for (int slot = 0; node = slots_.At(slot); ++slot) {
    if (node->path_ == p) {
      return slot;
    }
  }
  return -1;
}

int HTTP2Mount::doOpen(int slot) {
  HTTP2Node* node = slots_.At(slot);
  if (!node)
    return -1;

  if (node->pack_slot_ >= 0) {
    return doOpen(node->pack_slot_);
  }

  if (node->file_io_ || node->is_dir_)
    return 0;

  HTTP2OpenJob *job = new HTTP2OpenJob;
  job->url = base_url_ + node->path_;
  job->file_io_ = &node->file_io_;
  int ret = runner_->RunJob(job);
  if (ret != 0) {
    errno = EIO;
    return -1;
  }

  if (node->in_memory_) {
    char* buf = (char*)malloc(node->size_);
    int res = Read(slot, 0, buf, node->size_);
    if (res == node->size_) {
      node->data_ = buf;
      return 0;
    } else {
      free(buf);
      return -1;
    }
  }

  return 0;
}

int HTTP2Mount::GetNode(const std::string& path, struct stat* buf) {
  int slot = GetSlot(path);
  if (slot >= 0 && doOpen(slot) == 0)
      return Stat(slot, buf);
  return -1;
}

int HTTP2Mount::Stat(ino_t slot, struct stat *buf) {
  memset(buf, 0, sizeof(struct stat));
  HTTP2Node* node = slots_.At(slot);
  if (node == NULL) {
    errno = ENOENT;
    return -1;
  }
  buf->st_ino = (ino_t)slot;
  if (node->is_dir_) {
    buf->st_mode = S_IFDIR | 0777;
  } else {
    buf->st_mode = S_IFREG | 0777;
    buf->st_size = node->size_;
  }
  buf->st_uid = 1001;
  buf->st_gid = 1002;
  buf->st_blksize = 1024;
  return 0;
}

int HTTP2Mount::Getdents(ino_t slot, off_t offset,
                        struct dirent *dir, unsigned int count) {
  HTTP2Node* node = slots_.At(slot);
  if (node == NULL) {
    errno = ENOTDIR;
    return -1;
  }
  std::list<std::string> path_parts = Path(node->path_).path();
  std::set<std::string> entries;
  std::string pathslash = node->path_;
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
  return -1;
}

#define MIN(a,b) (a) < (b) ? (a) : (b)

ssize_t HTTP2Mount::Read(ino_t slot, off_t offset, void *buf, size_t count) {
  HTTP2Node* node = slots_.At(slot);
  if (!node || (!node->file_io_ && node->pack_slot_ < 0)) {
    errno = ENOENT;
    return -1;
  }

  // In the presence of packed files, we can not rely on FileIO to handle
  // clipping.
  offset = MIN(offset, node->size_);
  count = MIN(count, node->size_ - offset);
  if (count == 0)
    return 0;

  if (node->in_memory_ && node->data_) {
    memcpy(buf, node->data_ + offset, count);
    return count;
  }

  if (node->pack_slot_ >= 0) {
    return Read(node->pack_slot_, node->start_ + offset, buf, count);
  }

  HTTP2ReadJob* job = new HTTP2ReadJob();
  job->file_io_ = node->file_io_;
  job->offset_ = offset;
  job->buf_ = buf;
  job->nbytes_ = count;

  int ret = runner_->RunJob(job);
  if (ret < 0) {
    errno = EIO;
    return -1;
  }

  return ret;
}


int HTTP2Mount::AddPath(const std::string& path, size_t size, bool is_dir) {
  std::string p = Path(path).FormulatePath();

  int slot = slots_.Alloc();
  HTTP2Node *node = slots_.At(slot);
  node->slot_ = slot;
  node->path_ = p;
  node->file_io_ = NULL;
  node->pack_slot_ = -1;
  node->start_ = 0;
  node->size_ = size; // FIXME
  node->is_dir_ = is_dir;
  node->in_memory_ = false;
  node->data_ = NULL;

  files_.insert(p);
  return slot;
}

void HTTP2Mount::AddFile(const std::string& path, size_t size) {
  AddPath(path, size, false);
}

void HTTP2Mount::SetInMemory(const std::string& path, bool in_memory) {
  int slot = GetSlot(path);
  HTTP2Node *node = slots_.At(slot);
  if (node) {
    node->in_memory_ = in_memory;
  }
}

void HTTP2Mount::SetInPack(const std::string& path,
    const std::string& pack_path, off_t offset) {
  int slot = GetSlot(path);
  HTTP2Node *node = slots_.At(slot);
  if (node) {
    node->pack_slot_ = GetSlot(pack_path);
    node->start_ = offset;
    // TODO(eugenis): check that the file in the pack's byte range
    if (node->pack_slot_ < 0) {
      dbgprintf("Pack path not found: %s\n", pack_path.c_str());
    }
  }
}

void HTTP2Mount::AddDir(const std::string& path) {
  AddPath(path, 0, true);
}
