/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERFILEIOJOB_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERFILEIOJOB_H_

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

typedef enum {
  OPEN_FILE_SYSTEM = 0,
  OPEN_FILE,
  READ_FILE,
  WRITE_FILE,
  QUERY_FILE,
  NO_OP
} PepperFileOperation;

class PepperFileIOJob : public MainThreadJob {
 public:
  PepperFileIOJob();
  ~PepperFileIOJob();

  void set_op(PepperFileOperation op) { op_ = op; }
  void set_file_io(pp::FileIO *file_io) { file_io_ = file_io; }
  void set_file_ref(pp::FileRef *file_ref) { file_ref_ = file_ref; }
  void set_exp_size(int64_t exp_size) { exp_size_ = exp_size; }
  void set_offset(int64_t offset) { offset_ = offset; }
  void set_read_buf(char *read_buf) { read_buf_ = read_buf; }
  void set_write_buf(const char *write_buf) { write_buf_ = write_buf; }
  void set_nbytes(int32_t nbytes) { nbytes_ = nbytes; }
  void set_query_buf(PP_FileInfo *query_buf) { query_buf_ = query_buf; }
  void set_len(int64_t len) { len_ = len; }
  void set_flags(int32_t flags) { flags_ = flags; }
  void set_fs(pp::FileSystem *fs) { fs_ = fs; }

  void Run(MainThreadRunner::JobEntry *e);

 private:
  PepperFileOperation op_;
  pp::CompletionCallbackFactory<PepperFileIOJob> *factory_;
  pp::FileSystem *fs_;
  pp::FileIO *file_io_;
  pp::FileRef *file_ref_;
  int64_t exp_size_;
  int64_t offset_;
  char *read_buf_;
  const char *write_buf_;
  int32_t nbytes_;
  PP_FileInfo *query_buf_;
  int64_t len_;
  int32_t flags_;
  MainThreadRunner::JobEntry *job_entry_;

  void Finish(int32_t result);

  DISALLOW_COPY_AND_ASSIGN(PepperFileIOJob);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERFILEIOJOB_H_
