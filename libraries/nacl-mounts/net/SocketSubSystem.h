// Copyright (c) 2012 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_SOCKET_SUBSYSTEM_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_SOCKET_SUBSYSTEM_H_

#include <errno.h>
#include <stdarg.h>
#include <stdio.h>

#include <map>
#include <string>

#include "../base/KernelProxy.h"
#include "../net/BaseSocketSubSystem.h"
#include "../net/Socket.h"
#include "../ppapi/cpp/private/host_resolver_private.h"
#include "ppapi/utility/completion_callback_factory.h"

// current limitations:
// cannot close in another thread

class SocketSubSystem : public BaseSocketSubSystem {
 public:
  SocketSubSystem(pp::Instance* instance);
  virtual ~SocketSubSystem();
  pp::Instance* instance() { return pp_instance_; }

  // Syscall implementations
  int close(Socket* stream);
  int read(Socket* stream, char* buf, size_t count, size_t* nread);
  int write(Socket* stream, const char* buf, size_t count, size_t* nwrote);
  int seek(Socket* stream, nacl_abi_off_t offset, int whence,
           nacl_abi_off_t* new_offset);
  int fstat(Socket* stream, nacl_abi_stat* out);

  int fcntl(Socket* stream, int cmd, va_list ap);
  int ioctl(Socket* stream, int request, va_list ap);
  int setsockopt(Socket* stream, int level, int optname,
           const void* optval, socklen_t optlen);

  uint32_t gethostbyname(const char* name);
  int connect(Socket** stream, const sockaddr* serv_addr, socklen_t addrlen);
  int bind(Socket** stream, const sockaddr* addr, socklen_t addrlen);
  int shutdown(Socket* stream, int how);
  int listen(Socket* stream, int backlog);
  Socket* accept(Socket* stream, struct sockaddr *addr,
      socklen_t* addrlen);
  int getaddrinfo(const char* hostname, const char* servname,
    const addrinfo* hints, addrinfo** res);
  void freeaddrinfo(addrinfo* ai);
  int getnameinfo(const sockaddr* sa, socklen_t salen,
                            char* host, size_t hostlen,
                            char* serv, size_t servlen, int flags);
  Mutex& mutex() { return KernelProxy::KPInstance()->select_mutex(); }
  Cond& cond() { return KernelProxy::KPInstance()->select_cond(); }

 private:
  pp::Instance* pp_instance_;

  struct GetAddrInfoParams {
    const char* hostname;
    const char* servname;
    const struct addrinfo* hints;
    struct addrinfo** res;
  };

  uint32_t AddHostAddress(const char* name, uint32_t addr);
  addrinfo* CreateAddrInfo(const PP_NetAddress_Private& addr,
                           const addrinfo* hints,
                           const char* name);
  bool GetHostPort(const sockaddr* serv_addr, socklen_t addrlen,
                   std::string* hostname, uint16_t* port);
  void Resolve(int32_t result, GetAddrInfoParams* params, int32_t* pres);
  void OnResolve(int32_t result, GetAddrInfoParams* params, int32_t* pres);

  pp::CompletionCallbackFactory<SocketSubSystem, ThreadSafeRefCount> factory_;
  pp::HostResolverPrivate* host_resolver_;

  DISALLOW_COPY_AND_ASSIGN(SocketSubSystem);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_SOCKET_SUBSYSTEM_H_

