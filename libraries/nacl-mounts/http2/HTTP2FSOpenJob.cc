/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <assert.h>
#include <stdio.h>

#include "HTTP2FSOpenJob.h"
#include "../util/DebugPrint.h"


HTTP2FSOpenJob::HTTP2FSOpenJob() {
}

HTTP2FSOpenJob::~HTTP2FSOpenJob() {
}

void HTTP2FSOpenJob::Run(MainThreadRunner::JobEntry *e) {
  job_entry_ = e;
  factory_ = new pp::CompletionCallbackFactory<HTTP2FSOpenJob>(this);
  pp::CompletionCallback cc =
    factory_->NewCallback(&HTTP2FSOpenJob::FSOpenCallback);

  int32_t rv = fs_->Open(expected_size_, cc);
  if (rv != PP_OK_COMPLETIONPENDING)
    cc.Run(rv);
}

void HTTP2FSOpenJob::FSOpenCallback(int32_t result) {
  if (result != PP_OK) {
    dbgprintf("FileSystem open failed, %d\n", result);
    Finish(result);
  } else {
    Finish(result);
  }
}

void HTTP2FSOpenJob::Finish(int32_t result) {
  MainThreadRunner::ResultCompletion(job_entry_, result);
}
