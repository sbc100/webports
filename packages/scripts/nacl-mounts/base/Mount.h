/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_SCRIPTS_NACL_MOUNTS_BASE_MOUNT_H_
#define PACKAGES_SCRIPTS_NACL_MOUNTS_BASE_MOUNT_H_

#include <fcntl.h>
#include <sys/stat.h>
#include <string>
#include "../util/dirent.h"
#include "../util/macros.h"

// Mount serves as the base mounting class that will be used by
// the mount manager (class MountManager).  The mount manager
// relies heavily on the GetNode method as a way of directing
// system calls that take a path as an argument.  The methods
// of this class are pure virtual.  BaseMount class contains
// stub implementations for these methods.  Feel free to use
// BaseMount if your mount does not implement all of these
// operations.
class Mount {
 public:
  Mount() { ref_count_ = 0; }
  virtual ~Mount() {}

  // Given a path and a stat struct, return the inode associated with the path
  virtual int GetNode(const std::string& path, struct stat *st) = 0;

  // These methods are used by KernelProxy and MountManager
  void Ref(void) { ++ref_count_; }
  void Unref(void) { --ref_count_; }
  int ref_count(void) { return ref_count_; }

  // Increase the reference count for a given inode
  virtual void Ref(ino_t node) = 0;
  // Decrease the reference count for a given inode
  virtual void Unref(ino_t node) = 0;

  // System calls that can be overridden by a mount implementation
  virtual int Creat(const std::string& path, mode_t mode, struct stat *st) = 0;
  virtual int Mkdir(const std::string& path, mode_t mode, struct stat *st) = 0;
  virtual int Unlink(const std::string& path) = 0;
  virtual int Rmdir(ino_t node) = 0;
  virtual int Chmod(ino_t node, mode_t mode) = 0;
  virtual int Stat(ino_t node, struct stat *buf) = 0;
  virtual int Fsync(ino_t node) = 0;
  virtual int Getdents(ino_t node, off_t offset, struct dirent *dirp,
                       unsigned int count) = 0;
  virtual ssize_t Read(ino_t node, off_t offset, void *buf, size_t count) = 0;
  virtual ssize_t Write(ino_t node, off_t offset, const void *buf,
                        size_t count) = 0;
  virtual int Isatty(ino_t node) = 0;

 private:
  int ref_count_;

  DISALLOW_COPY_AND_ASSIGN(Mount);
};

#endif  // PACKAGES_SCRIPTS_NACL_MOUNTS_BASE_MOUNT_H_
