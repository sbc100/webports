/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERMOUNT_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERMOUNT_H_

#include <dirent.h>
#include <ppapi/cpp/file_system.h>
#include <pthread.h>
#include <map>
#include <set>
#include <string>
#include "../base/BaseMount.h"
#include "../util/Path.h"
#include "../util/SlotAllocator.h"
#include "PepperNode.h"
#include "PepperDirectoryReader.h"

class MainThreadRunner;

class PepperMount: public BaseMount {
 public:
  PepperMount(MainThreadRunner *runner, pp::FileSystem *fs, int64_t exp_size);
  virtual ~PepperMount() {}

  void SetDirectoryReader(DirectoryReader* reader) {
    directory_reader_ = reader;
  }
  void SetPathPrefix(const std::string& prefix) { path_prefix_ = prefix; }

  int GetSlot(const std::string& path);
  void Ref(ino_t node);
  void Unref(ino_t node);
  int GetNode(const std::string& path, struct stat *st);

  int Creat(const std::string& path, mode_t mode, struct stat *st);
  int Stat(ino_t node, struct stat *buf);
  ssize_t Read(ino_t node, off_t offset, void *buf, size_t count);
  ssize_t Write(ino_t node, off_t offset, const void *buf, size_t count);

  int Mkdir(const std::string& path, mode_t mode,
      struct stat *st);
  int Getdents(ino_t slot, off_t offset,
      struct dirent *dir, unsigned int count);
 private:
  SlotAllocator<PepperNode> slots_;
  pp::FileSystem *fs_;
  MainThreadRunner *runner_;
  std::map<std::string, int> path_map_;
  pthread_mutex_t pp_lock_;
  DirectoryReader* directory_reader_;
  std::string path_prefix_;

  int AllocateSlot(const std::string& path, bool create);

  DISALLOW_COPY_AND_ASSIGN(PepperMount);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERMOUNT_H_
