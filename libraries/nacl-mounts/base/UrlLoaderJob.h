/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_URLLOADERJOB_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_URLLOADERJOB_H_

#include <ppapi/c/pp_errors.h>
#include <ppapi/cpp/completion_callback.h>
#include <ppapi/cpp/url_loader.h>
#include <ppapi/cpp/url_request_info.h>
#include <ppapi/cpp/url_response_info.h>
#include <string>
#include <vector>
#include "MainThreadRunner.h"

class UrlLoaderJob : public MainThreadJob {
 public:
  UrlLoaderJob();
  ~UrlLoaderJob();

  // AppendField() adds the key and value to the request body
  // The key is the name of the form-data for Content-Disposition, and the
  // value is the associated data in the header. AppendField(key, val) adds
  // "Content-Disposition: form-data; name="key"" to the request body.
  // value is then inserted into the request body following the key.
  void AppendField(const std::string& key, const std::string& value);

  // AppendDataField() functions similarly to AppendField().  AppendDatafield()
  // adds the key and data to the request body in the same way.  length is the
  // number of bytes of data.  If free is set to true, data will be deleted
  // in the destructor.
  void AppendDataField(const std::string& key, const void *data, size_t length,
                       bool free);

  // Run() executes the URL request.  This method is called by a
  // MainThreadRunner object.
  void Run(MainThreadRunner::JobEntry *e);

  // Result is used to store information about the response to a URL request.
  // length stores how many bytes are in the content of the response.
  // status_code stores the HTTP status code of the response, e.g. 200
  struct Result {
    int length;
    int status_code;
  };

  void set_content_range(int start, int length) {
    start_ = start;
    length_ = length;
  }
  void set_method(const std::string& method) { method_ = method; }
  void set_dst(std::vector<char> *dst) { dst_ = dst; }
  void set_result_dst(Result *result_dst) { result_dst_ = result_dst; }
  void set_url(const std::string& url) { url_ = url; }

 private:
  struct FieldEntry {
    std:: string key;
    const char *data;
    int length;
    bool free_me;
  };

  void InitRequest(pp::URLRequestInfo *request);
  void OnOpen(int32_t result);
  void OnRead(int32_t result);
  void ReadMore();
  void ProcessResponseInfo(const pp::URLResponseInfo& response_info);
  void ProcessBytes(const char* bytes, int32_t length);
  int ParseContentLength(const std::string& headers);

  pp::CompletionCallbackFactory<UrlLoaderJob> *factory_;
  pp::URLLoader *loader_;
  MainThreadRunner::JobEntry *job_entry_;
  std::vector<FieldEntry> fields_;
  std::string url_;
  std::vector<char> *dst_;
  std::string method_;
  bool did_open_;
  int start_;
  int length_;
  Result *result_dst_;
  char buf_[4096];
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_URLLOADERJOB_H_
