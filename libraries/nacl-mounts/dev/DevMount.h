/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_DEV_DEVMOUNT_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_DEV_DEVMOUNT_H_

#include <map>
#include <string>
#include "../base/BaseMount.h"
#include "../dev/Device.h"
#include "../util/macros.h"

// DevMount
class DevMount: public BaseMount {
 public:
  DevMount();
  virtual ~DevMount() {}

  int GetNode(const std::string& path, struct stat* st);

  int Stat(ino_t node, struct stat *buf);
  int Mkdir(const std::string& path, mode_t mode, struct stat *st);
  ssize_t Read(ino_t node, off_t offset, void *buf, size_t count);
  ssize_t Write(ino_t node, off_t offset, const void *buf, size_t count);
  int Isatty(ino_t node) { return 0; }
  int Getdents(ino_t, off_t, dirent*, unsigned int);

  bool IsReadReady(ino_t node);
  bool IsWriteReady(ino_t node);
  bool IsException(ino_t node);

 private:
  std::map<int, std::string> inode_to_path;
  std::map<int, Device*> inode_to_dev;
  std::map<std::string, int> path_to_inode;
  int max_inode;
  void Attach(std::string path, Device* device);

  DISALLOW_COPY_AND_ASSIGN(DevMount);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_DEV_DEVMOUNT_H_

