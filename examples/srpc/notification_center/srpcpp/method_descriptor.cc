// Copyright (c) 2010 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "examples/srpc/notification_center/srpcpp/method_descriptor.h"

#include <nacl/nacl_srpc.h>
#include <cstring>

namespace srpcpp {

MethodDescriptor::MethodDescriptor() {
  entry_fmt = NULL;
  handler = NULL;
}

MethodDescriptor::~MethodDescriptor() {
  if (entry_fmt != NULL) {
    free(const_cast<char *>(entry_fmt));
  }
  // Don't try to delete a function pointer.  Probably a bad idea.
};

void MethodDescriptor::Init(const std::string& format,
                            NaClSrpcMethod method) {
  if (entry_fmt != NULL) {
    free(const_cast<char *>(entry_fmt));
  }
  // We have to use strndup to do this atomically since the content of the
  // pointer ends up being const protected)
  entry_fmt = strndup(format.c_str(), format.size() + 1);
  handler = method;
}
}  // namespace srpcpp
