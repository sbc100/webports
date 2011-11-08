/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include "buffer/BufferMount.h"
#include <assert.h>
#include <errno.h>
#include <string.h>
#include "util/SimpleAutoLock.h"


BufferMount::BufferMount(Mount* source, size_t chunk_size, size_t max_chunks) {
  source_ = source;
  chunk_size_ = chunk_size;
  max_chunks_ = max_chunks;
  assert(max_chunks_ > 0);
}

BufferMount::~BufferMount() {
}

int BufferMount::GetNode(const std::string& path, struct stat *st) {
  return source_->GetNode(path, st);
}

void BufferMount::Ref(ino_t node) {
  return source_->Ref(node);
}

void BufferMount::Unref(ino_t node) {
  InvalidateNode(node);
  return source_->Unref(node);
}

int BufferMount::Creat(const std::string& path, mode_t mode, struct stat *st) {
  return source_->Creat(path, mode, st);
}

int BufferMount::Mkdir(const std::string& path, mode_t mode, struct stat *st) {
  return source_->Mkdir(path, mode, st);
}

int BufferMount::Unlink(const std::string& path) {
  struct stat st;
  if (source_->GetNode(path, &st)) {
    errno = ENOENT;
    return -1;
  }
  InvalidateNode(st.st_ino);
  return source_->Unlink(path);
}

int BufferMount::Rmdir(ino_t node) {
  InvalidateNode(node);
  return source_->Rmdir(node);
}

int BufferMount::Chmod(ino_t node, mode_t mode) {
  return source_->Chmod(node, mode);
}

int BufferMount::Stat(ino_t node, struct stat *buf) {
  return source_->Stat(node, buf);
}

int BufferMount::Fsync(ino_t node) {
  return 0;
}

int BufferMount::Getdents(ino_t node, off_t offset, struct dirent *dirp,
                          unsigned int count) {
  return source_->Getdents(node, offset, dirp, count);
}

ssize_t BufferMount::Read(ino_t node, off_t offset, void *buf, size_t count) {
  char* bufc = reinterpret_cast<char*>(buf);
  size_t total = 0;
  while (total < count) {
    size_t count_clipped = count - total;
    if (count_clipped > chunk_size_) {
      count_clipped = chunk_size_;
    }
    ssize_t len = ReadBlock(node, offset, bufc, count_clipped);
    if (len < 0) {
      return len;
    }
    if (len == 0) {
      return total;
    }
    total += len;
    offset += len;
    bufc += len;
  }
  return total;
}

ssize_t BufferMount::Write(ino_t node, off_t offset, const void *buf,
                           size_t count) {
  InvalidateNode(node);
  return source_->Write(node, offset, buf, count);
}

int BufferMount::Isatty(ino_t node) {
  return source_->Isatty(node);
}

class BufferMount::CachedBlock {
 public:
  CachedBlock(ino_t node, off_t offset, char *data, size_t count) {
    node_ = node;
    offset_ = offset;
    data_ = data;
    count_ = count;
  }

  ~CachedBlock() {
    delete[] data_;
  }

  ino_t node() const { return node_; }
  off_t offset() const { return offset_; }
  char* data() const { return data_; }
  size_t count() const { return count_; }
 private:
  ino_t node_;
  off_t offset_;
  char* data_;
  size_t count_;
};

class BufferMount::CullByNode {
 public:
  explicit CullByNode(ino_t node) {
    node_ = node;
  }

  bool operator() (BufferMount::CachedBlock* block) {
    if (block->node() == node_) {
      delete block;
      return true;
    }
    return false;
  }

 private:
  ino_t node_;
};

void BufferMount::InvalidateNode(ino_t node) {
  SimpleAutoLock lock(&cache_lock_);
  cache_.remove_if(BufferMount::CullByNode(node));
}

void BufferMount::AddCachedBlock(ino_t node, off_t offset,
                                 char* data, size_t count) {
  SimpleAutoLock lock(&cache_lock_);

  // Drain old things from the cache.
  while (cache_.size() > max_chunks_ - 1) {
    delete cache_.back();
    cache_.pop_back();
  }

  // Add it.
  CachedBlock* block = new CachedBlock(node, offset, data, count);
  cache_.push_front(block);
}

ssize_t BufferMount::GetCachedBlock(ino_t node, off_t offset,
                                    char* data, size_t count) {
  SimpleAutoLock lock(&cache_lock_);
  off_t skip = offset % chunk_size_;
  offset = offset - skip;

  for (std::list<CachedBlock*>::iterator i = cache_.begin();
       i != cache_.end(); ++i) {
    if ((*i)->node() == node &&
        (*i)->offset() == offset) {
      if (count > (*i)->count() - skip) {
        count = (*i)->count() - skip;
      }
      if (count >= 0) {
        memcpy(data, (*i)->data() + skip, count);
      }
      // Bump to the front.
      CachedBlock* block = (*i);
      cache_.erase(i);
      cache_.push_front(block);
      return count;
    }
  }
  return -1;
}

ssize_t BufferMount::ReadBlock(ino_t node, off_t offset,
                               char* data, size_t count) {
  ssize_t sz;

  assert(count <= chunk_size_);

  // See if its in the cache.
  sz = GetCachedBlock(node, offset, data, count);
  if (sz >= 0) return sz;

  // Fetch it if not.
  char* buf = new char[chunk_size_];
  off_t noffset = offset / chunk_size_ * chunk_size_;
  sz = source_->Read(node, noffset, buf, chunk_size_);
  if (sz < 0) return sz;
  AddCachedBlock(node, noffset, buf, sz);

  // Now it should be in the cache.
  sz = GetCachedBlock(node, offset, data, count);
  assert(sz >= 0);
  return sz;
}
