// Copyright (c) 2010 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef EXAMPLES_SRPC_NOTIFICATION_CENTER_SRPCPP_METHOD_DESCRIPTOR_H_
#define EXAMPLES_SRPC_NOTIFICATION_CENTER_SRPCPP_METHOD_DESCRIPTOR_H_

#include <nacl/nacl_srpc.h>

#include <boost/shared_array.hpp>
#include <string>
#include <vector>

namespace srpcpp {
// this class's sole purpose is to add memory safety to the
// NaClSrpcHandlerDesc so the format strings don't have to be static const
class MethodDescriptor : public NaClSrpcHandlerDesc {
 public:
  MethodDescriptor();
  virtual ~MethodDescriptor();
  void Init(const std::string& format, NaClSrpcMethod method);
};

typedef std::vector<MethodDescriptor> MethodDescriptorVector;
typedef boost::shared_array<MethodDescriptor> MethodDescriptorSharedArray;

}  // namespace srpcpp
#endif  // EXAMPLES_SRPC_NOTIFICATION_CENTER_SRPCPP_METHOD_DESCRIPTOR_H_
