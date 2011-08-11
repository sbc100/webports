/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP_HTTPMOUNT_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP_HTTPMOUNT_H_

#include <dirent.h>
#include <set>
#include <string>
#include "../base/BaseMount.h"
#include "../base/MainThreadRunner.h"
#include "../base/UrlLoaderJob.h"
#include "../util/macros.h"
#include "../util/Path.h"
#include "../util/SlotAllocator.h"
#include "HTTPNode.h"

class MainThreadRunner;

class HTTPMount: public BaseMount {
 public:
  // runner is used to execute jobs on the main thread
  // base_url_ is the HTTP server to which the HTTPMount will make requests.
  // Note that the server may not support partial content requests, which
  // the HTTPMount relies upon for Read() calls.
  HTTPMount(MainThreadRunner *runner, std::string base_url);
  virtual ~HTTPMount() {}

  int Creat(const std::string& path, mode_t mode, struct stat* st);
  int GetNode(const std::string& path, struct stat* st);

  int Stat(ino_t node, struct stat *buf);
  int Getdents(ino_t node, off_t offset, struct dirent *dirp,
               unsigned int count);

  // If partial content requests are not supported by the server, Read()
  // will return -1.  Read() relies on the partial content request 206
  // status code.
  virtual ssize_t Read(ino_t node, off_t offset, void *buf, size_t count);

  // Add file to the list of files that the HTTPMount knows. AddFile() should
  // be called for each file that will be accessed by the HTTPMount.
  void AddFile(const std::string& file);

 private:
  HTTPNode *ToHTTPNode(ino_t node) {
    return slots_.At(node);
  }

  bool IsDir(const std::string& path);

  SlotAllocator<HTTPNode> slots_;
  MainThreadRunner *runner_;
  std::string base_url_;
  std::set<std::string> files_;

  DISALLOW_COPY_AND_ASSIGN(HTTPMount);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP_HTTPMOUNT_H_
