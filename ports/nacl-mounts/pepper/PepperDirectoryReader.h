/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERDIRECTORYREADER_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERDIRECTORYREADER_H_

#include <ppapi/cpp/completion_callback.h>
#include <string>

class DirectoryReader {
 public:
  virtual int ReadDirectory(const std::string& path,
      std::set<std::string>* entries, const pp::CompletionCallback& cc) = 0;
};

#endif // PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERDIRECTORYREADER_H_
