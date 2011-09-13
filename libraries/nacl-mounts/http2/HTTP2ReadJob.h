/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2READJOB_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2READJOB_H_

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


class HTTP2ReadJob : public MainThreadJob {
 public:
  HTTP2ReadJob();
  ~HTTP2ReadJob();

  void Run(MainThreadRunner::JobEntry *e);

  pp::FileIO* file_io_;
  off_t offset_;
  void* buf_;
  size_t nbytes_;

 private:
  pp::CompletionCallbackFactory<HTTP2ReadJob> *factory_;

  void ReadCallback(int32_t result);


  MainThreadRunner::JobEntry *job_entry_;

  void Finish(int32_t result);

  DISALLOW_COPY_AND_ASSIGN(HTTP2ReadJob);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2READJOB_H_
