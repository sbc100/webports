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
  PostMessageJob(const void *buf, size_t count) {
    buf_ = buf;
    count_ = count;
  }

  void Run(MainThreadRunner::JobEntry *e) {
    pp::Var msg = pp::Var(std::string(
        reinterpret_cast<const char*>(buf_), count_));
    pp::Instance *instance = MainThreadRunner::ExtractPepperInstance(e);
    instance->PostMessage(msg);
    MainThreadRunner::ResultCompletion(e, 0);
  }

 private:
  const void *buf_;
  size_t count_;
  void Done(int32_t result) {}

  DISALLOW_COPY_AND_ASSIGN(PostMessageJob);
};


void JSPostMessageBridge::Post(const void *buf, size_t count) {
  runner_->RunJob(new PostMessageJob(buf, count));
}
