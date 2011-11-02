/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include <ppapi/c/ppb_file_io.h>

#include "HTTP2OpenJob.h"
#include "../util/DebugPrint.h"


HTTP2OpenJob::HTTP2OpenJob() : factory_(NULL), loader_(NULL), ref_(NULL),
                               parent_ref_(NULL), io_(NULL) {
}

HTTP2OpenJob::~HTTP2OpenJob() {
}

void HTTP2OpenJob::Run(MainThreadRunner::JobEntry *e) {
  job_entry_ = e;

  dbgprintf("open %s\n", fs_path_.c_str());
  ref_ = new pp::FileRef(*fs_, fs_path_.c_str());
  pp::Instance *instance = MainThreadRunner::ExtractPepperInstance(job_entry_);
  io_ = new pp::FileIO(instance);

  factory_ = new pp::CompletionCallbackFactory<HTTP2OpenJob>(this);

  pp::CompletionCallback cc =
    factory_->NewCallback(&HTTP2OpenJob::FileOpenCallback);

  int32_t rv = io_->Open(*ref_, PP_FILEOPENFLAG_READ, cc);

  if (rv != PP_OK_COMPLETIONPENDING)
    cc.Run(rv);
}

pp::URLRequestInfo HTTP2OpenJob::MakeRequest(std::string url) {
  pp::Instance *instance = MainThreadRunner::ExtractPepperInstance(job_entry_);
  pp::URLRequestInfo request(instance);
  request.SetURL(url);
  request.SetMethod("GET");
  request.SetFollowRedirects(true);
  request.SetStreamToFile(false);
  request.SetAllowCredentials(true);
  request.SetAllowCrossOriginRequests(true);
  return request;
}

void HTTP2OpenJob::FileOpenCallback(int32_t result) {
  if (result == PP_OK) {
    // Open for reading succeded. Check that the file size is correct.
    pp::CompletionCallback cc =
      factory_->NewCallback(&HTTP2OpenJob::FileQueryCallback);

    int32_t rv = io_->Query(&query_buf_, cc);
    if (rv != PP_OK_COMPLETIONPENDING)
      cc.Run(rv);
  } else {
    // Open for reading failed. Create a new file.
    DownloadFile();
  }
}

void HTTP2OpenJob::FileQueryCallback(int32_t result) {
  if (result != PP_OK) {
    dbgprintf("Query failed, %d\n", result);
    Finish(result);
    return;
  }

  if (query_buf_.size < expected_size_) {
    // Bad/truncated file. Re-download.
    // TODO(eugenis): resume download if the file is shorter than expected
    io_->Close();
    DownloadFile();
  } else {
    // success
    *file_io_ = io_;
    io_ = NULL;
    Finish(result);
  }
}

void HTTP2OpenJob::DownloadFile() {
  dbgprintf("fetch %s\n", url_.c_str());

  // First, create a directory for the new file.
  pp::CompletionCallback cc =
    factory_->NewCallback(&HTTP2OpenJob::DirCreateCallback);

  parent_ref_ = new pp::FileRef(ref_->GetParent());

  if (parent_ref_->GetPath().AsString() == "/") {
    cc.Run(PP_ERROR_FILEEXISTS);
  } else {
    int32_t rv = parent_ref_->MakeDirectoryIncludingAncestors(cc);
    if (rv != PP_OK_COMPLETIONPENDING)
      cc.Run(rv);
  }
}

void HTTP2OpenJob::DirCreateCallback(int32_t result) {
  if (result != PP_OK && result != PP_ERROR_FILEEXISTS) {
    dbgprintf("Could not create a directory in the local fs: %s, %d\n",
        parent_ref_->GetPath().AsString().c_str(), result);
    Finish(result);
    return;
  }

  if (result == PP_ERROR_FILEEXISTS) {
    dbgprintf("Dir already exists. That's fine.\n");
  }

  pp::CompletionCallback cc =
    factory_->NewCallback(&HTTP2OpenJob::FileCreateCallback);

  int32_t rv = io_->Open(*ref_,
      PP_FILEOPENFLAG_CREATE | PP_FILEOPENFLAG_READ | PP_FILEOPENFLAG_WRITE,
      cc);

  if (rv != PP_OK_COMPLETIONPENDING)
    cc.Run(rv);
}

void HTTP2OpenJob::FileCreateCallback(int32_t result) {
  if (result != PP_OK) {
    dbgprintf("file creation failed: %d\n", result);
    Finish(result);
    return;
  }

  offset_ = 0;
  write_in_flight_ = false;
  read_done_ = false;

  loader_ =
    new pp::URLLoader(MainThreadRunner::ExtractPepperInstance(job_entry_));
  pp::CompletionCallback cc =
    factory_->NewCallback(&HTTP2OpenJob::UrlOpenCallback);

  int32_t rv = loader_->Open(MakeRequest(url_), cc);
  if (rv != PP_OK_COMPLETIONPENDING)
    cc.Run(rv);
}

void HTTP2OpenJob::UrlOpenCallback(int32_t result) {
  if (result != PP_OK) {
    dbgprintf("Open failed, %d\n", result);
    Finish(result);
    return;
  }

  const pp::URLResponseInfo& response_info = loader_->GetResponseInfo();
  int status_code = response_info.GetStatusCode();
  if (status_code != 200) {
    dbgprintf("bad status code %d\n", status_code);
    Finish(-status_code);
    return;
  }

  ReadMore();
}

void HTTP2OpenJob::ReadMore() {
  pp::CompletionCallback cc =
    factory_->NewCallback(&HTTP2OpenJob::UrlReadCallback);
  int32_t rv = loader_->ReadResponseBody(read_buf_, sizeof(read_buf_), cc);
  if (rv != PP_OK_COMPLETIONPENDING) {
    cc.Run(rv);
  }
}

void HTTP2OpenJob::UrlReadCallback(int32_t result) {
  if (result < 0) {
    dbgprintf("Read failed, %d\n", result);
    Finish(result);
    return;
  }

  if (result == 0) {
    read_done_ = true;
    MaybeDone();
  }

  if (result > 0) {
    // append data to the write buffer
    size_t pos = write_buf_.size();
    write_buf_.resize(pos + result);
    memcpy(&write_buf_[pos], read_buf_, result);

    MaybeWrite();

    // continue reading
    ReadMore();
  }
}

void HTTP2OpenJob::MaybeWrite() {
  if (write_in_flight_)
    return;
  if (write_buf_.empty()) {
    MaybeDone();
  } else {
    pp::CompletionCallback cc =
      factory_->NewCallback(&HTTP2OpenJob::FileWriteCallback);
    int32_t rv =
      io_->Write(offset_, &write_buf_.front(), write_buf_.size(), cc);
    write_in_flight_ = true;
    if (rv != PP_OK_COMPLETIONPENDING) {
      cc.Run(rv);
    }
  }
}

void HTTP2OpenJob::MaybeDone() {
  if (!write_in_flight_ && write_buf_.empty() && read_done_) {
    *file_io_ = io_;
    io_ = NULL;
    Finish(0);
    return;
  }
}

void HTTP2OpenJob::ReportProgress() {
  if (progress_handler_)
    progress_handler_->HandleProgress(path_, offset_, expected_size_);
}

void HTTP2OpenJob::FileWriteCallback(int32_t result) {
  write_in_flight_ = false;
  if (result <= 0) {
    dbgprintf("Write failed\n");
    Finish(result);
    return;
  }

  // result > 0
  offset_ += result;
  write_buf_.erase(write_buf_.begin(), write_buf_.begin() + result);

  ReportProgress();

  MaybeWrite();
}

void HTTP2OpenJob::Finish(int32_t result) {
  delete factory_;
  delete loader_;
  delete ref_;
  delete parent_ref_;
  delete io_;
  MainThreadRunner::ResultCompletion(job_entry_, result);
}
