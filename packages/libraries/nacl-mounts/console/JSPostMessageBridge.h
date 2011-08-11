/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_CONSOLE_JSPOSTMESSAGEBRIDGE_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_CONSOLE_JSPOSTMESSAGEBRIDGE_H_

#include "../base/MainThreadRunner.h"
#include "../util/macros.h"
#include "JSPipeMount.h"

// Interface for outbound pipe pool.
class JSPostMessageBridge : public JSOutboundPipeBridge {
 public:
  JSPostMessageBridge(MainThreadRunner *runner) {
    runner_ = runner;
  }

  void Post(const void *buf, size_t count);

 private:
  MainThreadRunner *runner_;

  DISALLOW_COPY_AND_ASSIGN(JSPostMessageBridge);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_CONSOLE_JSPOSTMESSAGEBRIDGE_H_
