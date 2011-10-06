/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef LIBRARIES_NACL_MOUNTS_BUFFER_BUFFERMOUNT_H_
#define LIBRARIES_NACL_MOUNTS_BUFFER_BUFFERMOUNT_H_

#include <pthread.h>
#include <list>
#include <string>
#include "base/Mount.h"
#include "buffer/BufferMount.h"

class BufferMount : public Mount {
 public:
  BufferMount(Mount* source, size_t chunk_size, size_t max_chunks);
  virtual ~BufferMount();

  virtual int GetNode(const std::string& path, struct stat *st);
  virtual void Ref(ino_t node);
  virtual void Unref(ino_t node);
  virtual int Creat(const std::string& path, mode_t mode, struct stat *st);
  virtual int Mkdir(const std::string& path, mode_t mode, struct stat *st);
  virtual int Unlink(const std::string& path);
  virtual int Rmdir(ino_t node);
  virtual int Chmod(ino_t node, mode_t mode);
  virtual int Stat(ino_t node, struct stat *buf);
  virtual int Fsync(ino_t node);
  virtual int Getdents(ino_t node, off_t offset, struct dirent *dirp,
                       unsigned int count);
  virtual ssize_t Read(ino_t node, off_t offset, void *buf, size_t count);
  virtual ssize_t Write(ino_t node, off_t offset, const void *buf,
                        size_t count);
  virtual int Isatty(ino_t node);

 private:
  size_t chunk_size_;
  size_t max_chunks_;
  Mount* source_;

  class CachedBlock;
  class CullByNode;
  std::list<CachedBlock*> cache_;
  pthread_mutex_t cache_lock_;
  void InvalidateNode(ino_t node);
  void AddCachedBlock(ino_t node, off_t offset, char *buf, size_t count);
  ssize_t GetCachedBlock(ino_t node, off_t offset, char *buf, size_t count);
  ssize_t ReadBlock(ino_t node, off_t offset, char *buf, size_t count);

  DISALLOW_COPY_AND_ASSIGN(BufferMount);
};

#endif  // LIBRARIES_NACL_MOUNTS_BUFFER_BUFFERMOUNT_H_
