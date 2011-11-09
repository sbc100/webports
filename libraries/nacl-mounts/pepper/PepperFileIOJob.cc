/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <assert.h>
#include "../util/DebugPrint.h"
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
  file_io_p_ = NULL;
  path_ = "";
}

PepperFileIOJob::~PepperFileIOJob() {
}

void PepperFileIOJob::Run(MainThreadRunner::JobEntry *e) {
  job_entry_ = e;
  factory_ = new pp::CompletionCallbackFactory<PepperFileIOJob>(this);
  pp::CompletionCallback cc = factory_->NewCallback(&PepperFileIOJob::Finish);
  pp::Instance *instance = MainThreadRunner::ExtractPepperInstance(e);

  int32_t rv;
  switch (op_) {
  case OPEN_FILE_SYSTEM:
    assert(fs_);
    rv = fs_->Open(exp_size_, cc);
    break;

  case OPEN_FILE:
    assert(file_io_p_);
    file_ref_ = new pp::FileRef(*fs_, path_.c_str());
    *file_io_p_ = new pp::FileIO(instance);
    rv = (*file_io_p_)->Open(*file_ref_, flags_, cc);
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

  case CLOSE_FILE:
    assert(file_io_);
    file_io_->Close();
    delete file_io_;
    cc.Run(PP_OK);
    break;

  case MAKE_DIR:
    file_ref_ = new pp::FileRef(*fs_, path_.c_str());
    rv = file_ref_->MakeDirectoryIncludingAncestors(cc); // FIXME
    break;

  case READ_DIR:
    directory_reader_->ReadDirectory(path_, dir_entries_, cc);
    break;

  }

}

void PepperFileIOJob::Finish(int32_t result) {
  delete file_ref_;
  if (result != PP_OK && file_io_p_)
    delete *file_io_p_;
  MainThreadRunner::ResultCompletion(job_entry_, result);
}
