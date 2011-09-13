/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <assert.h>
#include <stdio.h>

#include <ppapi/c/ppb_file_io.h>

#include "HTTP2ReadJob.h"
#include "../util/DebugPrint.h"


HTTP2ReadJob::HTTP2ReadJob() {
}

HTTP2ReadJob::~HTTP2ReadJob() {
}

void HTTP2ReadJob::Run(MainThreadRunner::JobEntry *e) {
  job_entry_ = e;
  factory_ = new pp::CompletionCallbackFactory<HTTP2ReadJob>(this);
  pp::CompletionCallback cc =
    factory_->NewCallback(&HTTP2ReadJob::ReadCallback);

  int32_t rv = file_io_->Read(offset_, (char*)buf_, nbytes_, cc);
  if (rv != PP_OK_COMPLETIONPENDING)
    cc.Run(rv);
}

void HTTP2ReadJob::ReadCallback(int32_t result) {
  if (result < PP_OK) {
    dbgprintf("Read failed, %d\n", result);
    fflush(stderr);
    Finish(result);
    return;
  } else {
    Finish(result);
  }
}

void HTTP2ReadJob::Finish(int32_t result) {
  MainThreadRunner::ResultCompletion(job_entry_, result);
}
