// Copyright (c) 2010 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "examples/srpc/notification_center/srpcpp/method_container.h"

#include <nacl/nacl_srpc.h>

#include <string>

namespace srpcpp {

MethodContainer::MethodContainer() : methods_() {}
MethodContainer::~MethodContainer() {}

void MethodContainer::Add(const std::string& format, NaClSrpcMethod method) {
  MethodDescriptor method_descriptor;
  method_descriptor.Init(format, method);
  methods_.push_back(method_descriptor);
}

MethodDescriptorSharedArray MethodContainer::GetMethodHandlers() const {
  MethodDescriptorSharedArray srpc_method_array;
  MethodDescriptorVector::size_type method_count(methods_.size());
  srpc_method_array.reset(new MethodDescriptor[method_count + 1]);
  for (MethodDescriptorVector::size_type i = 0; i < method_count; ++i) {
    // This is deliberately a second copy of the descriptor so that the
    // pointers in the shared array remain valid even if this container
    // ceases to exist.  We don't own this data once it is shared.
    srpc_method_array[i].Init(methods_[i].entry_fmt, methods_[i].handler);
  }
  return srpc_method_array;
}
}  // namespace srpcpp
