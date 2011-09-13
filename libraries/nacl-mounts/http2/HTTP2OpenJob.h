/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2OPENJOB_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2OPENJOB_H_

#include <ppapi/c/pp_errors.h>
#include <ppapi/c/pp_file_info.h>
#include <ppapi/cpp/completion_callback.h>
#include <ppapi/cpp/file_io.h>
#include <ppapi/cpp/file_ref.h>
#include <ppapi/cpp/file_system.h>
#include <ppapi/cpp/url_loader.h>
#include <ppapi/cpp/url_request_info.h>
#include <ppapi/cpp/url_response_info.h>
#include <string>
#include <vector>
#include "../base/MainThreadRunner.h"
#include "../util/macros.h"


class HTTP2OpenJob : public MainThreadJob {
 public:
  HTTP2OpenJob();
  ~HTTP2OpenJob();

  void Run(MainThreadRunner::JobEntry *e);

  std::string url;
  pp::FileIO** file_io_;

 private:
  pp::CompletionCallbackFactory<HTTP2OpenJob> *factory_;

  pp::URLLoader* loader_;

  pp::URLRequestInfo MakeRequest(std::string url);
  void OpenCallback(int32_t result);
  void FinishStreamingToFileCallback(int32_t result);
  void OpenFileBodyCallback(int32_t result);

  MainThreadRunner::JobEntry *job_entry_;

  void Finish(int32_t result);

  DISALLOW_COPY_AND_ASSIGN(HTTP2OpenJob);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2OPENJOB_H_
