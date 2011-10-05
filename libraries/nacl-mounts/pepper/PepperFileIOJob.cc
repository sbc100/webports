/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <assert.h>
#include "PepperFileIOJob.h"

PepperFileIOJob::PepperFileIOJob() {
  op_ = NO_OP;
  fs_ = NULL;
  exp_size_ = 0;
  offset_ = 0;
  file_io_ = NULL;
  file_ref_ = NULL;
  read_buf_ = NULL;
  write_buf_ = NULL;
  nbytes_ = 0;
  query_buf_ = NULL;
  len_ = 0;
  flags_ = 0;
}

PepperFileIOJob::~PepperFileIOJob() {
}

void PepperFileIOJob::Run(MainThreadRunner::JobEntry *e) {
  job_entry_ = e;
  factory_ = new pp::CompletionCallbackFactory<PepperFileIOJob>(this);
  pp::CompletionCallback cc = factory_->NewCallback(&PepperFileIOJob::Finish);

  int32_t rv;
  switch (op_) {
    case OPEN_FILE_SYSTEM:
      assert(fs_);
      rv = fs_->Open(exp_size_, cc);
      break;

    case OPEN_FILE:
      assert(file_io_);
      rv = file_io_->Open(*file_ref_, flags_, cc);
      break;

    case READ_FILE:
      assert(file_io_);
      rv = file_io_->Read(offset_, read_buf_, nbytes_, cc);
      break;

    case WRITE_FILE:
      assert(file_io_);
      rv = file_io_->Write(offset_, write_buf_, nbytes_, cc);
      break;

    case QUERY_FILE:
      assert(file_io_);
      rv = file_io_->Query(query_buf_, cc);
      break;
  }
}

void PepperFileIOJob::Finish(int32_t result) {
  MainThreadRunner::ResultCompletion(job_entry_, result);
}
