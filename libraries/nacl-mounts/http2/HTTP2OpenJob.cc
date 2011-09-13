/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <assert.h>
#include <stdio.h>

#include <ppapi/c/ppb_file_io.h>

#include "HTTP2OpenJob.h"
#include "../util/DebugPrint.h"


HTTP2OpenJob::HTTP2OpenJob() {
}

HTTP2OpenJob::~HTTP2OpenJob() {
}

void HTTP2OpenJob::Run(MainThreadRunner::JobEntry *e) {
  job_entry_ = e;
  loader_ = new pp::URLLoader(MainThreadRunner::ExtractPepperInstance(e));
  factory_ = new pp::CompletionCallbackFactory<HTTP2OpenJob>(this);
  pp::CompletionCallback cc =
    factory_->NewCallback(&HTTP2OpenJob::OpenCallback);

  int32_t rv = loader_->Open(MakeRequest(url), cc);
  if (rv != PP_OK_COMPLETIONPENDING)
    cc.Run(rv);
}

pp::URLRequestInfo HTTP2OpenJob::MakeRequest(std::string url) {
  pp::Instance *instance = MainThreadRunner::ExtractPepperInstance(job_entry_);
  pp::URLRequestInfo request(instance);
  request.SetURL(url);
  request.SetMethod("GET");
  request.SetFollowRedirects(true);
  request.SetStreamToFile(true);
  request.SetAllowCredentials(true);
  request.SetAllowCrossOriginRequests(true);
  return request;
}

void HTTP2OpenJob::OpenCallback(int32_t result) {
  if (result != PP_OK) {
    dbgprintf("Open failed, %d\n", result);
    Finish(result);
    return;
  }

  const pp::URLResponseInfo& response_info = loader_->GetResponseInfo();
  int status_code = response_info.GetStatusCode();
  if (status_code != 200) {
    dbgprintf("bad status code %d\n", status_code);
    Finish(1);
    return;
  }

  pp::CompletionCallback cc =
    factory_->NewCallback(&HTTP2OpenJob::FinishStreamingToFileCallback);
  int32_t rv = loader_->FinishStreamingToFile(cc);
  if (rv != PP_OK_COMPLETIONPENDING)
    cc.Run(rv);
}

void HTTP2OpenJob::FinishStreamingToFileCallback(int32_t result) {
  if (result != PP_OK) {
    dbgprintf("FinishStreamingToFile failed, %d\n", result);
    Finish(result);
    return;
  }

  const pp::URLResponseInfo& response_info = loader_->GetResponseInfo();
  pp::FileRef fileref = response_info.GetBodyAsFileRef();
  if (fileref.is_null()) {
    dbgprintf("GetFileBodyAsRef failed");
    Finish(1);
    return;
  }

  pp::Instance *instance = MainThreadRunner::ExtractPepperInstance(job_entry_);
  *file_io_ = new pp::FileIO(instance);
  pp::CompletionCallback cc =
    factory_->NewCallback(&HTTP2OpenJob::OpenFileBodyCallback);
  int32_t rv = (*file_io_)->Open(fileref, PP_FILEOPENFLAG_READ, cc);
  if (rv != PP_OK_COMPLETIONPENDING)
    cc.Run(rv);
}

void HTTP2OpenJob::OpenFileBodyCallback(int32_t result) {
  if (result != PP_OK) {
    dbgprintf("FileIO::Open failed, %d\n", result);
    delete (*file_io_);
    Finish(result);
    return;
  }

  Finish(0);
}

void HTTP2OpenJob::Finish(int32_t result) {
  MainThreadRunner::ResultCompletion(job_entry_, result);
}
