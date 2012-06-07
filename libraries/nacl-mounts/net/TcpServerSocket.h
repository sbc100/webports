// Copyright (c) 2012 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_NET_TCP_SERVER_SOCKET_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_NET_TCP_SERVER_SOCKET_H_

#include <string>
#include "../net/SocketSubSystem.h"
#include "ppapi/cpp/completion_callback.h"
#include "../ppapi/cpp/private/tcp_server_socket_private.h"
#include "../util/PthreadHelpers.h"

class TCPServerSocket : public Socket {
 public:
  TCPServerSocket(SocketSubSystem* sys,
      int oflag, const sockaddr* saddr, socklen_t addrlen);
  virtual ~TCPServerSocket();

  bool is_open() { return socket_ != NULL; }

  virtual void addref();
  virtual void release();

  virtual int read(char* buf, size_t count, size_t* nread);
  virtual int write(const char* buf, size_t count, size_t* nwrote);
  virtual void close();

  virtual int fcntl(int cmd,  va_list ap);

  virtual bool is_read_ready();
  virtual bool is_write_ready();
  virtual bool is_exception();

  bool listen(int backlog);
  PP_Resource accept();

 private:
  void Listen(int32_t result, int backlog, int32_t* pres);
  void Accept(int32_t result, int32_t* pres);
  void OnAccept(int32_t result);
  void Close(int32_t result, int32_t* pres);
  bool CreateNetAddress(const sockaddr* saddr, PP_NetAddress_Private* addr);

  SocketSubSystem* sys_;
  int ref_;
  int oflag_;
  pp::CompletionCallbackFactory<TCPServerSocket, ThreadSafeRefCount> factory_;
  pp::TCPServerSocketPrivate* socket_;
  sockaddr_in6 sin6_;
  PP_Resource resource_;

  DISALLOW_COPY_AND_ASSIGN(TCPServerSocket);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_NET_TCP_SERVER_SOCKET_H_

