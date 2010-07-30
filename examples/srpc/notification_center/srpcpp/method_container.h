// Copyright (c) 2010 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef EXAMPLES_SRPC_NOTIFICATION_CENTER_SRPCPP_METHOD_CONTAINER_H_
#define EXAMPLES_SRPC_NOTIFICATION_CENTER_SRPCPP_METHOD_CONTAINER_H_

#include "examples/srpc/notification_center/srpcpp/method_descriptor.h"

#include <nacl/nacl_srpc.h>

#include <boost/noncopyable.hpp>
#include <string>

namespace srpcpp {
typedef std::vector<NaClSrpcHandlerDesc> HandlerDescriptorVector;
// This class's job is to provide a dynamic container of MethodDescriptors
// that can return a C-style array of the same, in a way that is memory safe.
// The envisioned usage is for socket listening loops that may discard this
// container and won't want to clean up the NaClSrpcHandlerDesc array when
// they exit.  Add and GetMethodHandlers are not threadsafe.
class MethodContainer : private boost::noncopyable {
 public:
  MethodContainer();
  virtual ~MethodContainer();

  void Add(const std::string& format, NaClSrpcMethod method);

  NaClSrpcHandlerDesc * GetMethodHandlers() const;
 private:
  //MethodDescriptorVector methods_;
};
}  // namespace srpcpp
#endif  // EXAMPLES_SRPC_NOTIFICATION_CENTER_SRPCPP_METHOD_CONTAINER_H_
