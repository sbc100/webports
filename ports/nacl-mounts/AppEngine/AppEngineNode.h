/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_APPENGINE_APPENGINENODE_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_APPENGINE_APPENGINENODE_H_

#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <list>
#include <string>
#include <vector>
#include "../util/macros.h"

class AppEngineMount;

// The AppEngineNode class is used by the AppEngineMount to represent files
// and directories.  Data is stored in memory in an AppEngineNode.
class AppEngineNode {
 public:
  AppEngineNode();
  ~AppEngineNode() {}

  // Reallocate the capacity the capacity of the data to len bytes
  void ReallocData(int len);

  int use_count(void) { return use_count_; }
  void IncrementUseCount(void) { ++use_count_; }
  void DecrementUseCount(void) { --use_count_; }

  // Write count bytes of buf to this node, starting at the given offset
  int WriteData(off_t offset, const void *buf, size_t count);

  char *data(void);
  void set_data(std::vector<char> data) { WriteData(0, &data[0], data.size()); }

  std::string path() { return path_; }
  void set_path(const std::string& path) { path_ = path; }

  int slot(void) { return slot_; }
  void set_slot(int slot) { slot_ = slot; }

  bool is_dir() { return is_dir_; }
  bool is_dir_known() { return is_dir_known_; }
  void set_is_dir(bool is_dir) { is_dir_ = is_dir; is_dir_known_ = true; }

  // len() returns the number of bytes of data written to this node
  size_t len(void) { return len_; }

  // is_dirty() returns true if data has been written to this node
  // at least once.  Otherwise, false is returned.
  bool is_dirty(void) { return is_dirty_; }
  void set_is_dirty(bool is_dirty) { is_dirty_ = is_dirty; }

 private:
  int parent_;
  char *data_;
  size_t len_;
  bool is_dir_;
  bool is_dir_known_;
  int use_count_;
  std::string path_;
  int slot_;
  bool is_dirty_;
  int capacity_;

  DISALLOW_COPY_AND_ASSIGN(AppEngineNode);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_APPENGINE_APPENGINENODE_H_
