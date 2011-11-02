/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2PROGRESSHANDLER_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2PROGRESSHANDLER_H_

class HTTP2ProgressHandler {
 public:
  virtual void HandleProgress(std::string& path, int64_t bytes,
      int64_t size) = 0;
};

#endif // PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2PROGRESSHANDLER_H_
