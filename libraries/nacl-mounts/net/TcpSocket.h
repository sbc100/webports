// Copyright (c) 2012 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_NET_SOCKET_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_NET_SOCKET_H_

#include <deque>
#include <queue>
#include <vector>

#include "../net/Socket.h"
#include "../net/SocketSubSystem.h"
#include "ppapi/cpp/completion_callback.h"
#include "../ppapi/cpp/private/tcp_socket_private.h"
#include "../util/PthreadHelpers.h"

class TCPSocket : public Socket {
 public:
  TCPSocket(SocketSubSystem* sys, int oflag);
  virtual ~TCPSocket();

  int oflag() { return oflag_; }
  bool is_block() { return !(oflag_ & O_NONBLOCK); }
  bool is_open() { return socket_ != NULL; }

  bool connect(const char* host, uint16_t port);
  bool acceptFrom(PP_Resource resource);

  virtual void addref();
  virtual void release();

  virtual void close();
  virtual int read(char* buf, size_t count, size_t* nread);
  virtual int write(const char* buf, size_t count, size_t* nwrote);

  virtual int fcntl(int cmd,  va_list ap);

  virtual bool is_read_ready();
  virtual bool is_write_ready();
  virtual bool is_exception();

  void GetAddress(struct sockaddr* addr);
 private:
  void Connect(int32_t result, const char* host, uint16_t port, int32_t* pres);
  void OnConnect(int32_t result, int32_t* pres);

  void Read(int32_t result, int32_t* pres);
  void OnRead(int32_t result, int32_t* pres);

  void Write(int32_t result, int32_t* pres);
  void OnWrite(int32_t result, int32_t* pres);

  void Close(int32_t result, int32_t* pres);

  bool Accept(int32_t result, PP_Resource resource, int32_t* pres);

  static const size_t kBufSize = 64 * 1024;

  SocketSubSystem* sys_;
  int ref_;
  int oflag_;
  pp::CompletionCallbackFactory<TCPSocket, ThreadSafeRefCount> factory_;
  pp::TCPSocketPrivate* socket_;
  std::deque<char> in_buf_;
  std::vector<char> out_buf_;
  std::vector<char> read_buf_;
  std::vector<char> write_buf_;
  bool write_sent_;

  DISALLOW_COPY_AND_ASSIGN(TCPSocket);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_NET_SOCKET_H_

