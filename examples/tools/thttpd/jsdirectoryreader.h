/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifndef __JSDIRECTORYREADER_H__
#define __JSDIRECTORYREADER_H__
#include <nacl-mounts/base/BaseMount.h>
#include <nacl-mounts/base/KernelProxy.h>
#include <nacl-mounts/base/MountManager.h>
#include <nacl-mounts/pepper/PepperDirectoryReader.h>

#include <cstdio>
#include <map>
#include <set>
#include <string>

#include "ppapi/cpp/completion_callback.h"
#include "ppapi/cpp/file_system.h"
#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/module.h"
#include "ppapi/cpp/rect.h"
#include "ppapi/cpp/size.h"
#include "ppapi/cpp/var.h"

class JSDirectoryReader : public DirectoryReader {
  int id;
 public:
  typedef std::set<std::string>* entries_type;
  pp::Instance* instance_;
  std::map<int, entries_type> entries_;
  std::map<int, pp::CompletionCallback> cc_;

  JSDirectoryReader(pp::Instance* instance) : instance_(instance), id(0) {}

  int ReadDirectory(const std::string& path,
    std::set<std::string>* entries, const pp::CompletionCallback& cc);
  void HandleResponse(const std::string& response);
};

#endif

