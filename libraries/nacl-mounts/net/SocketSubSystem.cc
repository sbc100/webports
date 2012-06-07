// Copyright (c) 2012 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <string.h>
#ifdef __GLIBC__
#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>
#else
#include <nacl-mounts/net/newlib_compat.h>
#endif
#include <irt.h>
#include <nacl-mounts/net/SocketSubSystem.h>
#include <nacl-mounts/net/TcpServerSocket.h>
#include <nacl-mounts/net/TcpSocket.h>
#include <nacl-mounts/ppapi/cpp/private/net_address_private.h>
#include <nacl-mounts/util/DebugPrint.h>
#include <nacl-mounts/util/PthreadHelpers.h>
#include "ppapi/cpp/file_ref.h"
#include <signal.h>

SocketSubSystem::SocketSubSystem(pp::Instance* instance)
    : pp_instance_(instance)
    , factory_(this)
    , host_resolver_(NULL) {
  AddHostAddress("localhost", 0x7F000001);
}

uint32_t SocketSubSystem::AddHostAddress(const char* name, uint32_t addr) {
  return addr;
}

struct addrinfo* SocketSubSystem::CreateAddrInfo(
    const PP_NetAddress_Private& netaddr,
    const addrinfo* hints,
    const char* name) {
  struct addrinfo* ai = new addrinfo();
  struct sockaddr_in6* addr = new sockaddr_in6();

  ai->ai_addr = reinterpret_cast<sockaddr*>(addr);
  ai->ai_addrlen = sizeof(*addr);

  PP_NetAddressFamily_Private family =
      pp::NetAddressPrivate::GetFamily(netaddr);
  if (family == PP_NETADDRESSFAMILY_IPV4)
    ai->ai_addr->sa_family = ai->ai_family = AF_INET;
  else if (family == PP_NETADDRESSFAMILY_IPV6)
    ai->ai_addr->sa_family = ai->ai_family = AF_INET6;

  ai->ai_canonname = strdup(name);
  addr->sin6_port = pp::NetAddressPrivate::GetPort(netaddr);
  if (family == PP_NETADDRESSFAMILY_IPV6) {
    pp::NetAddressPrivate::GetAddress(
        netaddr, &addr->sin6_addr, sizeof(in6_addr));
  } else {
    pp::NetAddressPrivate::GetAddress(
        netaddr, &(reinterpret_cast<sockaddr_in*>(addr))->sin_addr,
        sizeof(in_addr));
  }

  if (hints && hints->ai_socktype)
    ai->ai_socktype = hints->ai_socktype;
  else
    ai->ai_socktype = SOCK_STREAM;

  if (hints && hints->ai_protocol)
    ai->ai_protocol = hints->ai_protocol;

  return ai;
}

int SocketSubSystem::getaddrinfo(const char* hostname, const char* servname,
    const addrinfo* hints, addrinfo** res) {
  SimpleAutoLock lock(mutex());
  GetAddrInfoParams params;
  params.hostname = hostname;
  params.servname = servname;
  params.hints = hints;
  params.res = res;
  int32_t result = PP_OK_COMPLETIONPENDING;
  pp::Module::Get()->core()->CallOnMainThread(0, factory_.NewCallback(
      &SocketSubSystem::Resolve, &params, &result));
  while (result == PP_OK_COMPLETIONPENDING)
    cond().wait(mutex());
  return result == PP_OK ? 0 : EAI_FAIL;
}

void SocketSubSystem::Resolve(int32_t result, GetAddrInfoParams* params,
                         int32_t* pres) {
  SimpleAutoLock lock(mutex());
  const char* hostname = params->hostname;
  const char* servname = params->servname;
  const addrinfo* hints = params->hints;
  addrinfo** res = params->res;

  if (hints && hints->ai_family != AF_UNSPEC &&
      hints->ai_family != AF_INET &&
      hints->ai_family != AF_INET6) {
    *pres = PP_ERROR_FAILED;
    cond().broadcast();
    dbgprintf("SSS::Resolve failed: incorrect ai_family\n");
    return;
  }

  uint32_t port = 0;
  if (servname != NULL) {
    char* cp;
    port = strtol(servname, &cp, 10);
    if (port > 0 && port <= 65535 && *cp == '\0') {
      port = htons(port);
    } else {
      dbgprintf("Bad port number %s\n", servname);
      port = 0;
    }
  }

  bool is_ipv6 = hints ? hints->ai_family == AF_INET6 : false;
  in6_addr in = {};
  bool is_numeric = hostname &&
      inet_pton(is_ipv6 ? AF_INET6 : AF_INET, hostname, &in);

  if (is_numeric) {
    PP_NetAddress_Private addr = {};
    if (is_ipv6) {
      // TODO(dpolukhin): handle scope_id
      if (!pp::NetAddressPrivate::CreateFromIPv6Address(
              in.s6_addr, 0, port, &addr)) {
        dbgprintf("NetAddressPrivate::CreateFromIPv6Address failed!\n");
        *pres = PP_ERROR_FAILED;
        cond().broadcast();
        return;
      }
    } else {
      if (!pp::NetAddressPrivate::CreateFromIPv4Address(
              in.s6_addr, port, &addr)) {
        dbgprintf("NetAddressPrivate::CreateFromIPv4Address failed!\n");
        *pres = PP_ERROR_FAILED;
        cond().broadcast();
        return;
      }
    }
    *res = CreateAddrInfo(addr, hints, "");
    *pres = PP_OK;
    cond().broadcast();
    return;
  }

  if (hints && hints->ai_flags & AI_PASSIVE) {
    // Numeric case we considered above so the only remaining case is any.
    PP_NetAddress_Private addr = {};
    if (!pp::NetAddressPrivate::GetAnyAddress(is_ipv6, &addr)) {
      dbgprintf("NetAddressPrivate::GetAnyAddress failed!\n");
      *pres = PP_ERROR_FAILED;
      cond().broadcast();
      return;
    }
    *res = CreateAddrInfo(addr, hints, "");
    *pres = PP_OK;
    cond().broadcast();
    return;
  }

  if (!hostname) {
    PP_NetAddress_Private localhost = {};
    if (is_ipv6) {
      uint8_t localhost_ip[16] = {};
      localhost_ip[15] = 1;
      // TODO(dpolukhin): handle scope_id
      if (!pp::NetAddressPrivate::CreateFromIPv6Address(
              localhost_ip, 0, port, &localhost)) {
        dbgprintf("NetAddressPrivate::CreateFromIPv6Address failed!\n");
        *pres = PP_ERROR_FAILED;
        cond().broadcast();
        return;
      }
    } else {
      uint8_t localhost_ip[4] = { 127, 0, 0, 1 };
      if (!pp::NetAddressPrivate::CreateFromIPv4Address(
              localhost_ip, port, &localhost)) {
        dbgprintf("NetAddressPrivate::CreateFromIPv4Address failed!\n");
        *pres = PP_ERROR_FAILED;
        cond().broadcast();
        return;
      }
    }
    *res = CreateAddrInfo(localhost, hints, "");
    *pres = PP_OK;
    cond().broadcast();
    return;
  }

  if (hints && hints->ai_flags & AI_NUMERICHOST) {
    dbgprintf("SSS::Resolve failed (AI_NUMERICHOST)\n");
    *pres = PP_ERROR_FAILED;
    cond().broadcast();
    return;
  }

  // In case of JS socket don't use local host resolver.
  if (pp::HostResolverPrivate::IsAvailable()) {
    PP_HostResolver_Private_Hint hint = { PP_NETADDRESSFAMILY_UNSPECIFIED, 0 };
    if (hints) {
      if (hints->ai_family == AF_INET)
        hint.family = PP_NETADDRESSFAMILY_IPV4;
      else if (hints->ai_family == AF_INET6)
        hint.family = PP_NETADDRESSFAMILY_IPV6;
      if (hints->ai_flags & AI_CANONNAME)
        hint.flags = PP_HOST_RESOLVER_FLAGS_CANONNAME;
    }

    assert(host_resolver_ == NULL);
    host_resolver_ = new pp::HostResolverPrivate(instance());
    *pres = host_resolver_->Resolve(hostname, port, hint,
        factory_.NewCallback(&SocketSubSystem::OnResolve, params, pres));
    if (*pres != PP_OK_COMPLETIONPENDING) {
      delete host_resolver_;
      host_resolver_ = NULL;
      cond().broadcast();
    }
  } else {
    dbgprintf("NetAddress resolver not available\n");
    *res = NULL;
    *pres = PP_ERROR_FAILED;
    cond().broadcast();
    return;
  }
}

void SocketSubSystem::OnResolve(int32_t result, GetAddrInfoParams* params,
                           int32_t* pres) {
  SimpleAutoLock lock(mutex());
  assert(host_resolver_);
  const struct addrinfo* hints = params->hints;
  struct addrinfo** res = params->res;
  std::string host_name = host_resolver_->GetCanonicalName().AsString();
  if (result == PP_OK) {
    size_t size  = host_resolver_->GetSize();
    for (size_t i = 0; i < size; i++) {
      PP_NetAddress_Private address = {};
      if (host_resolver_->GetNetAddress(i, &address)) {
        *res = CreateAddrInfo(address, hints, host_name.c_str());
        res = &(*res)->ai_next;
      }
    }
  } else {
    result = PP_ERROR_FAILED;
  }
  delete host_resolver_;
  host_resolver_ = NULL;
  *pres = result;
  cond().broadcast();
}

void SocketSubSystem::freeaddrinfo(addrinfo* ai) {
  while (ai != NULL) {
    struct addrinfo* next = ai->ai_next;
    free(ai->ai_canonname);
    delete ai->ai_addr;
    delete ai;
    ai = next;
  }
}

int SocketSubSystem::getnameinfo(const sockaddr *sa, socklen_t salen,
                            char* host, size_t hostlen,
                            char* serv, size_t servlen, int flags) {
  if (sa->sa_family != AF_INET && sa->sa_family != AF_INET6)
    return EAI_FAMILY;

  if (serv) {
    snprintf(serv, servlen, "%d",
      ntohs((reinterpret_cast<const sockaddr_in*>(sa))->sin_port));
  }
  if (host) {
    if (sa->sa_family == AF_INET6) {
      inet_ntop(AF_INET6,
        &(reinterpret_cast<const sockaddr_in6*>(sa))->sin6_addr,
        host, hostlen);
    }
  } else {
      inet_ntop(AF_INET, &(reinterpret_cast<const sockaddr_in*>(sa))->sin_addr,
        host, hostlen);
  }

  return 0;
}

bool SocketSubSystem::GetHostPort(const sockaddr* serv_addr, socklen_t addrlen,
                             std::string* hostname, uint16_t* port) {
  if (serv_addr->sa_family == AF_INET) {
    const sockaddr_in* sin4 = reinterpret_cast<const sockaddr_in*>(serv_addr);
    *port = ntohs(sin4->sin_port);
    char buf[NI_MAXHOST];
    inet_ntop(AF_INET, &sin4->sin_addr, buf, sizeof(buf));
    *hostname = buf;
  } else {
    const sockaddr_in6* sin6 = reinterpret_cast<const sockaddr_in6*>(serv_addr);
    *port = ntohs(sin6->sin6_port);
    char buf[NI_MAXHOST];
    inet_ntop(AF_INET6, &sin6->sin6_addr, buf, sizeof(buf));
    *hostname = buf;
  }
  return true;
}

int SocketSubSystem::connect(Socket** stream, const sockaddr* serv_addr,
    socklen_t addrlen) {
  uint16_t port;
  std::string hostname;
  if (!GetHostPort(serv_addr, addrlen, &hostname, &port)) {
    errno = EAFNOSUPPORT;
    return -1;
  }

  TCPSocket* socket = new TCPSocket(this, O_RDWR);
  if (!socket->connect(hostname.c_str(), port)) {
    errno = ECONNREFUSED;
    socket->release();
    return -1;
  }
  *stream = socket;

  return 0;
}

int SocketSubSystem::bind(Socket** stream, const sockaddr* addr,
    socklen_t addrlen) {
  *stream = (new TCPServerSocket(this, 0, addr, addrlen));
  return 0;
}

uint32_t SocketSubSystem::gethostbyname(const char* name) {
  struct addrinfo* ai;
  struct addrinfo hints;
  hints.ai_family = AF_INET;
  hints.ai_flags = 0;
  if (!getaddrinfo(name, "80", &hints, &ai)) {
    uint32_t ip = ((struct sockaddr_in*)ai->ai_addr)->sin_addr.s_addr;
    return ip;
  } else {
    dbgprintf("getaddrinfo returned AI_FAIL\n");
    return NULL;
  }
}

SocketSubSystem::~SocketSubSystem() {
}

int SocketSubSystem::shutdown(Socket* stream, int how) {
  if (stream) {
    // Actually shutdown should be something more complicated by for now
    // it works. Method close can be called multiple time.
    stream->close();
    return 0;
  } else {
    errno = EBADF;
    return -1;
  }
}

int SocketSubSystem::close(Socket* stream) {
  if (stream) {
    stream->close();
    stream->release();
  }
  return 0;
}

int SocketSubSystem::read(Socket* stream, char* buf, size_t count,
    size_t* nread) {
  if (stream)
    return stream->read(buf, count, nread);
  else
    return EBADF;
}

int SocketSubSystem::write(Socket* stream, const char* buf, size_t count,
    size_t* nwrote) {
  if (stream)
    return stream->write(buf, count, nwrote);
  else
    return EBADF;
}

int SocketSubSystem::seek(Socket* stream, nacl_abi_off_t offset, int whence,
                     nacl_abi_off_t* new_offset) {
  if (stream)
    return stream->seek(offset, whence, new_offset);
  else
    return EBADF;
}

int SocketSubSystem::fstat(Socket* stream, nacl_abi_stat* out) {
  if (stream)
    return stream->fstat(out);
  else
    return EBADF;
}

int SocketSubSystem::fcntl(Socket* stream, int cmd, va_list ap) {
  if (stream) {
    return stream->fcntl(cmd, ap);
  } else {
    errno = EBADF;
    return -1;
  }
}

int SocketSubSystem::ioctl(Socket* stream, int request, va_list ap) {
  if (stream) {
    return stream->ioctl(request, ap);
  } else {
    errno = EBADF;
    return -1;
  }
}

int SocketSubSystem::listen(Socket* stream, int backlog) {
  if (stream) {
    if (static_cast<TCPServerSocket*>(stream)->listen(backlog)) {
      return 0;
    } else {
      errno = EACCES;
      return -1;
    }
  } else {
    errno = EBADF;
    return -1;
  }
}

Socket* SocketSubSystem::accept(Socket* stream, struct sockaddr *addr,
    socklen_t* addrlen) {
  if (stream) {
    PP_Resource resource = static_cast<TCPServerSocket*>(stream)->accept();
    if (resource) {
      TCPSocket* socket = new TCPSocket(this, O_RDWR);
      if (socket->acceptFrom(resource)) {
        return socket;
      } else {
        socket->release();
      }
    }
    errno = EINVAL;
    return 0;
  } else {
    errno = EBADF;
    return 0;
  }
}

