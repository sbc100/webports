/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2FSOPENJOB_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2FSOPENJOB_H_

#include <ppapi/c/pp_errors.h>
#include <ppapi/c/pp_file_info.h>
#include <ppapi/cpp/completion_callback.h>
#include <ppapi/cpp/file_system.h>
#include <string>
#include <vector>
#include "../base/MainThreadRunner.h"
#include "../util/macros.h"


class HTTP2FSOpenJob : public MainThreadJob {
 public:
  HTTP2FSOpenJob();
  ~HTTP2FSOpenJob();

  void Run(MainThreadRunner::JobEntry *e);

  pp::FileSystem* fs_;
  int64_t expected_size_;

 private:
  pp::CompletionCallbackFactory<HTTP2FSOpenJob> *factory_;

  void FSOpenCallback(int32_t result);


  MainThreadRunner::JobEntry *job_entry_;

  void Finish(int32_t result);

  DISALLOW_COPY_AND_ASSIGN(HTTP2FSOpenJob);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2FSOPENJOB_H_
