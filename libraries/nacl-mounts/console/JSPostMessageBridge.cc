/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/var.h>
#include <string>
#include "console/JSPostMessageBridge.h"


class PostMessageJob : public MainThreadJob {
 public:
  PostMessageJob(const void *buf, size_t count) :
    msg_(reinterpret_cast<const char*>(buf), count) {
  }

  void Run(MainThreadRunner::JobEntry *e) {
    pp::Var msg = pp::Var(msg_);
    pp::Instance *instance = MainThreadRunner::ExtractPepperInstance(e);
    instance->PostMessage(msg);
    MainThreadRunner::ResultCompletion(e, 0);
  }

 private:
  std::string msg_;
  void Done(int32_t result) {}

  DISALLOW_COPY_AND_ASSIGN(PostMessageJob);
};


void JSPostMessageBridge::Post(const void *buf, size_t count) {
  runner_->RunJobAsync(new PostMessageJob(buf, count));
}
