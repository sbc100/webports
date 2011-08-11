/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP_HTTPNODE_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP_HTTPNODE_H_

#include <string>

class HTTPNode {
 public:
  int use_count;
  int slot;
  std::string path;
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP_HTTPNODE_H_
