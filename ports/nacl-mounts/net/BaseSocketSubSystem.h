// Copyright (c) 2012 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_NET_BASESOCKETSUBSYSTEM_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_NET_BASESOCKETSUBSYSTEM_H_
#include <errno.h>
#ifndef __GLIBC__
#include <nacl-mounts/net/newlib_compat.h>
#else
#include <netdb.h>
#endif
#include <nacl-mounts/net/Socket.h>
#include <nacl-mounts/util/PthreadHelpers.h>
#include <stdarg.h>
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>

#include <map>
#include <string>

class BaseSocketSubSystem {
 public:
  BaseSocketSubSystem() {}
  virtual ~BaseSocketSubSystem() {}

  // Syscall implementations
  virtual int close(Socket* stream) = 0;
  virtual int read(Socket* stream, char* buf, size_t count,
    size_t* nread) = 0;
  virtual int write(Socket* stream, const char* buf, size_t count,
    size_t* nwrote) = 0;
  virtual int seek(Socket* stream, nacl_abi_off_t offset, int whence,
           nacl_abi_off_t* new_offset) = 0;
  virtual int fstat(Socket* stream, nacl_abi_stat* out) = 0;

  virtual int fcntl(Socket* stream, int cmd, va_list ap) = 0;
  virtual int ioctl(Socket* stream, int request, va_list ap) = 0;
  virtual int setsockopt(Socket* stream, int level, int optname,
           const void* optval, socklen_t optlen) = 0;

  virtual uint32_t gethostbyname(const char* name) = 0;
  virtual int getaddrinfo(const char* hostname, const char* servname,
    const addrinfo* hints, addrinfo** res) = 0;
  virtual void freeaddrinfo(addrinfo* ai) = 0;
  virtual int getnameinfo(const struct sockaddr* sa, socklen_t salen,
                          char* host, size_t hostlen,
                          char* serv, size_t servlen, int flags) = 0;
  virtual int connect(Socket** stream, const struct sockaddr* serv_addr,
    socklen_t addrlen) = 0;
  virtual int bind(Socket** stream, const sockaddr* addr,
    socklen_t addrlen) = 0;
  virtual int shutdown(Socket* stream, int how) = 0;
  virtual int listen(Socket* stream, int backlog) = 0;
  virtual Socket* accept(Socket* stream, sockaddr *addr,
    socklen_t* addrlen) = 0;
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_NET_BASESOCKETSUBSYSTEM_H_

