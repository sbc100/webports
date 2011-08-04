/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <stdio.h>
#include <string.h>
#include "UrlLoaderJob.h"

#define BOUNDARY_STRING_HEADER "n4(1+60061E(|20|^^|34TW1234567890!$\n"
#define BOUNDARY_STRING_SEP "--n4(1+60061E(|20|^^|34TW1234567890!$\r\n"
#define BOUNDARY_STRING_END "--n4(1+60061E(|20|^^|34TW1234567890!$--\r\n"

UrlLoaderJob::UrlLoaderJob() {
  start_ = -1;
  did_open_ = false;
  result_dst_ = NULL;
  method_ = "GET";
}

UrlLoaderJob::~UrlLoaderJob() {
  for (std::vector<FieldEntry>::iterator it = fields_.begin();
      it != fields_.end(); ++it) {
    if (it->free_me) {
      delete[] it->data;
    }
  }
}

void UrlLoaderJob::AppendField(const std::string& key,
                               const std::string& value) {
  char *data = new char[value.size()];
  memcpy(data, value.c_str(), value.size());
  AppendDataField(key, data, value.size(), true);
}

void UrlLoaderJob::AppendDataField(const std::string& key, const void *data,
                                   size_t length, bool free) {
  FieldEntry e;
  e.key = key;
  e.data = reinterpret_cast<const char *>(data);
  e.length = length;
  e.free_me = free;
  fields_.push_back(e);
}

void UrlLoaderJob::Run(MainThreadRunner::JobEntry *e) {
  job_entry_ = e;
  loader_ = new pp::URLLoader(MainThreadRunner::ExtractPepperInstance(e));
  factory_ = new pp::CompletionCallbackFactory<UrlLoaderJob>(this);
  pp::CompletionCallback cc = factory_->NewCallback(&UrlLoaderJob::OnOpen);
  pp::URLRequestInfo request(MainThreadRunner::ExtractPepperInstance(e));
  InitRequest(&request);
  int32_t rv = loader_->Open(request, cc);
  if (rv != PP_OK_COMPLETIONPENDING) {
    cc.Run(rv);
  }
}

void UrlLoaderJob::InitRequest(pp::URLRequestInfo *request) {
  request->SetURL(url_);
  request->SetMethod(method_);
  request->SetFollowRedirects(true);
  request->SetAllowCredentials(true);
  request->SetAllowCrossOriginRequests(true);
  std::string headers;
  if (start_ >= 0) {
    headers += "Content-Range: ";
    headers += start_;
    headers += "-";
    headers += (start_ + length_);
    headers += "/*\n";
  }
  if (method_ == "POST") {
    headers += "Content-Type: multipart/form-data; charset=utf-8; boundary=";
    headers += BOUNDARY_STRING_HEADER;
    std::vector<FieldEntry>::iterator it;
    for (it = fields_.begin(); it != fields_.end(); ++it) {
      if (it != fields_.begin()) {
        request->AppendDataToBody("\n", 1);
      }
      request->AppendDataToBody(BOUNDARY_STRING_SEP,
                                sizeof(BOUNDARY_STRING_SEP) - 1);
      std::string line = "Content-Disposition: form-data; name=\"" + it->key
                         + "\"\n\n";
      request->AppendDataToBody(line.c_str(), line.size());
      request->AppendDataToBody(it->data, it->length);
    }
    request->AppendDataToBody("\n", 1);
    request->AppendDataToBody(BOUNDARY_STRING_END,
                              sizeof(BOUNDARY_STRING_END) - 1);
  }
  request->SetHeaders(headers);
}

void UrlLoaderJob::OnOpen(int32_t result) {
  if (result >= 0) {
    ReadMore();
  } else {
    // TODO(arbenson): provide a more meaningful completion result
    MainThreadRunner::ResultCompletion(job_entry_, 0);
    delete this;
  }
}

void UrlLoaderJob::OnRead(int32_t result) {
  if (result > 0) {
    ProcessBytes(buf_, result);
    ReadMore();
  } else if (result == PP_OK && !did_open_) {
    // Headers are available, and we can start reading the body.
    did_open_ = true;
    ProcessResponseInfo(loader_->GetResponseInfo());
    ReadMore();
  } else {
    // TODO(arbenson): provide a more meaningful completion result
    MainThreadRunner::ResultCompletion(job_entry_, 0);
    delete this;
  }
}

void UrlLoaderJob::ReadMore() {
  pp::CompletionCallback cc = factory_->NewCallback(&UrlLoaderJob::OnRead);
  int32_t rv = loader_->ReadResponseBody(buf_, sizeof(buf_), cc);
  if (rv != PP_OK_COMPLETIONPENDING) {
    cc.Run(rv);
  }
}

void UrlLoaderJob::ProcessResponseInfo(
    const pp::URLResponseInfo& response_info) {
  if (!result_dst_) {
    return;
  }
  result_dst_->status_code = response_info.GetStatusCode();
  std::string headers = response_info.GetHeaders().AsString();
  static const char *kCONTENT_LENGTH = "Content-Length: ";
  ssize_t pos = headers.find(kCONTENT_LENGTH);
  result_dst_->length = -1;
  if (pos != headers.size()) {
    sscanf(headers.c_str() + pos + sizeof(kCONTENT_LENGTH), "%d",
           &result_dst_->length);
  }
}

void UrlLoaderJob::ProcessBytes(const char* bytes, int32_t length) {
  if (!dst_) {
    return;
  }
  assert(length >= 0);
  std::vector<char>::size_type pos = dst_->size();
  dst_->resize(pos + length);
  memcpy(&(*dst_)[pos], bytes, length);
}
