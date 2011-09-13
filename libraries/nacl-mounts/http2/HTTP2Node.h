/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2NODE_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2NODE_H_

#include <string>
#include <ppapi/cpp/file_io.h>

class HTTP2Node {
 public:
  pp::FileIO* file_io_;
  size_t start_;
  ssize_t size_;
  bool is_dir_;

  int slot_;
  int pack_slot_; // -1 if not in a bundle
  std::string path_;

  bool in_memory_;
  char* data_; // optional; entire file contents
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2NODE_H_
