/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifndef __SHELLJOB_H__
#define __SHELLJOB_H__
#include <nacl-mounts/base/MainThreadRunner.h>
#include <nacl-mounts/util/DebugPrint.h>
#include <string>
#include "ppapi/cpp/file_system.h"
#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/module.h"
#include "ppapi/cpp/var.h"

class ShellJob : public MainThreadJob {
  std::string message;
  pp::Instance& instance;
  MainThreadRunner::JobEntry* entry_;
 public:
  ShellJob(const std::string& message, pp::Instance& instance)
    : message(message)
    , instance(instance)
  { }

  void Run(MainThreadRunner::JobEntry *entry) {
    entry_ = entry;
    instance.PostMessage(pp::Var(message));
    Finish(0);
  }

  void Finish(int32_t result) {
    MainThreadRunner::ResultCompletion(entry_, result);
  }
};

#endif

