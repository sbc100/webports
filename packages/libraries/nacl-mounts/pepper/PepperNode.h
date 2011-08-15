/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERNODE_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERNODE_H_

#include <ppapi/cpp/file_io.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <string>
#include "../util/macros.h"

// The PepperNode class is used by the PepperMount to represent files
// and directories.
class PepperNode {
 public:
  PepperNode() {
    use_count_ = 0;
    is_dir_ = false;
  }
  ~PepperNode() {}

  int use_count(void) { return use_count_; }
  void IncrementUseCount(void) { ++use_count_; }
  void DecrementUseCount(void) { --use_count_; }

  std::string path() { return path_; }
  void set_path(const std::string& path) { path_ = path; }

  int slot(void) { return slot_; }
  void set_slot(int slot) { slot_ = slot; }

  pp::FileIO *file_io() { return file_io_; }
  void set_file_io(pp::FileIO *file_io) { file_io_ = file_io; }

  bool is_dir(void) { return is_dir_; }
  void set_is_dir(bool is_dir) { is_dir_ = is_dir; }

 private:
  pp::FileIO *file_io_;
  int use_count_;
  std::string path_;
  int slot_;
  bool is_dir_;

  DISALLOW_COPY_AND_ASSIGN(PepperNode);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERNODE_H_
