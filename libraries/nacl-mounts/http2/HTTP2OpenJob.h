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
#include "HTTP2ProgressHandler.h"

class HTTP2OpenJob : public MainThreadJob {
 public:
  HTTP2OpenJob();
  ~HTTP2OpenJob();

  void Run(MainThreadRunner::JobEntry *e);

  // Remote URL.
  std::string url_; // in

  // Local cache path.
  std::string fs_path_; // in

  // Nice looking path (or just textual description) for progress reporting.
  std::string path_; // in

  // Expected file size. Used to verify locally cached copy.
  int64_t expected_size_; // in

  // HTML5 file system used as the local cache.
  pp::FileSystem* fs_; // in

  // Download progress is reported through this handle.
  HTTP2ProgressHandler* progress_handler_; // in

  // Opened FileIO in the local cache.
  pp::FileIO** file_io_; // out

 private:
  pp::CompletionCallbackFactory<HTTP2OpenJob> *factory_;

  pp::URLLoader* loader_;
  pp::FileRef* ref_;
  pp::FileRef* parent_ref_;
  pp::FileIO* io_;
  PP_FileInfo query_buf_;

  // File offset of the first byte of write_buf_.
  int64_t offset_;

  // Local file write buffer.
  std::vector<char> write_buf_;

  // URLLoader read buffer.
  char read_buf_[4096];

  // Whether there is a pending write request.
  bool write_in_flight_;

  // Whether remote fetch is complete.
  bool read_done_;

  pp::URLRequestInfo MakeRequest(std::string url);
  void FileOpenCallback(int32_t result);
  void FileQueryCallback(int32_t result);
  void DirCreateCallback(int32_t result);
  void FileCreateCallback(int32_t result);
  void UrlOpenCallback(int32_t result);
  void UrlReadCallback(int32_t result);
  void FileWriteCallback(int32_t result);

  void DownloadFile();
  void ReadMore();
  void MaybeWrite();
  void MaybeDone();
  void ReportProgress();

  MainThreadRunner::JobEntry *job_entry_;

  void Finish(int32_t result);

  DISALLOW_COPY_AND_ASSIGN(HTTP2OpenJob);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2OPENJOB_H_
