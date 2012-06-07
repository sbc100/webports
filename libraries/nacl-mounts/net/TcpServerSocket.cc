// Copyright (c) 2012 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "net/TcpServerSocket.h"

#include <assert.h>
#include <string.h>

#include "../net/SocketSubSystem.h"
#include "ppapi/c/pp_errors.h"
#include "ppapi/cpp/module.h"
#include "ppapi/cpp/private/net_address_private.h"
#include "../util/DebugPrint.h"
#include "../util/PthreadHelpers.h"

TCPServerSocket::TCPServerSocket(SocketSubSystem* sys, int oflag,
                                 const sockaddr* saddr, socklen_t addrlen)
  : ref_(1), oflag_(oflag), factory_(this), socket_(NULL),
    resource_(0), sys_(sys) {
  assert(sizeof(sin6_) >= addrlen);
  memcpy(&sin6_, saddr, std::min(sizeof(sin6_), addrlen));
}

TCPServerSocket::~TCPServerSocket() {
  assert(!socket_);
  assert(!ref_);
}

void TCPServerSocket::addref() {
  ++ref_;
}

void TCPServerSocket::release() {
  if (!--ref_)
    delete this;
}

int TCPServerSocket::read(char* buf, size_t count, size_t* nread) {
  return -1;
}

int TCPServerSocket::write(const char* buf, size_t count, size_t* nwrote) {
  return -1;
}

void TCPServerSocket::close() {
  SimpleAutoLock lock(sys_->mutex());
  if (socket_) {
    int32_t result = PP_OK_COMPLETIONPENDING;
    pp::Module::Get()->core()->CallOnMainThread(0,
        factory_.NewCallback(&TCPServerSocket::Close, &result));
    while (result == PP_OK_COMPLETIONPENDING)
      sys_->cond().wait(sys_->mutex());
  }
}

int TCPServerSocket::fcntl(int cmd,  va_list ap) {
  if (cmd == F_GETFL) {
    return oflag_;
  } else if (cmd == F_SETFL) {
    oflag_ = va_arg(ap, long);
    return 0;
  } else {
    return -1;
  }
}

bool TCPServerSocket::is_read_ready() {
  return !is_open() || resource_;
}

bool TCPServerSocket::is_write_ready() {
  return !is_open();
}

bool TCPServerSocket::is_exception() {
  return !is_open();
}

bool TCPServerSocket::listen(int backlog) {
  SimpleAutoLock lock(sys_->mutex());
  int32_t result = PP_OK_COMPLETIONPENDING;
  pp::Module::Get()->core()->CallOnMainThread(0,
      factory_.NewCallback(&TCPServerSocket::Listen, backlog, &result));
  while (result == PP_OK_COMPLETIONPENDING)
    sys_->cond().wait(sys_->mutex());
  return result == PP_OK;
}

PP_Resource TCPServerSocket::accept() {
  if (!resource_)
    return 0;

  PP_Resource ret = resource_;
  resource_ = 0;
  pp::Module::Get()->core()->CallOnMainThread(0,
      factory_.NewCallback(&TCPServerSocket::Accept,
                           static_cast<int32_t*>(NULL)));

  return ret;
}

bool TCPServerSocket::CreateNetAddress(const sockaddr* saddr,
                                       PP_NetAddress_Private* addr) {
  if (saddr->sa_family == AF_INET) {
    const sockaddr_in* sin4 = reinterpret_cast<const sockaddr_in*>(saddr);
    if (!pp::NetAddressPrivate::CreateFromIPv4Address(
            reinterpret_cast<const uint8_t*>(&sin4->sin_addr),
            ntohs(sin4->sin_port), addr)) {
      return false;
    }
  } else {
    const sockaddr_in6* sin6 = reinterpret_cast<const sockaddr_in6*>(saddr);
    if (!pp::NetAddressPrivate::CreateFromIPv6Address(
            reinterpret_cast<const uint8_t*>(&sin6->sin6_addr), 0,
            ntohs(sin6->sin6_port), addr)) {
      return false;
    }
  }
  return true;
}

void TCPServerSocket::Listen(int32_t result, int backlog, int32_t* pres) {
  SimpleAutoLock lock(sys_->mutex());
  assert(!socket_);
  socket_ = new pp::TCPServerSocketPrivate(sys_->instance());

  PP_NetAddress_Private addr = {};
  if (CreateNetAddress(reinterpret_cast<const sockaddr*>(&sin6_), &addr)) {
    dbgprintf("TCPServerSocket::Listen: %s\n",
        pp::NetAddressPrivate::Describe(addr, true).c_str());
    *pres = socket_->Listen(&addr, backlog,
        factory_.NewCallback(&TCPServerSocket::Accept, pres));
  } else {
    dbgprintf("Listen failed: %s\n",
        pp::NetAddressPrivate::Describe(addr, true).c_str());
    *pres = PP_ERROR_FAILED;
  }
  if (*pres != PP_OK_COMPLETIONPENDING) {
    sys_->cond().broadcast();
  }
}

void TCPServerSocket::Accept(int32_t result, int32_t* pres) {
  SimpleAutoLock lock(sys_->mutex());
  assert(socket_);
  if (result == PP_OK) {
    result = socket_->Accept(&resource_,
        factory_.NewCallback(&TCPServerSocket::OnAccept));
    if (result == PP_OK_COMPLETIONPENDING)
      result = PP_OK;
  }
  if (pres)
    *pres = result;
  sys_->cond().broadcast();
}

void TCPServerSocket::OnAccept(int32_t result) {
  SimpleAutoLock lock(sys_->mutex());
  assert(socket_);
  sys_->cond().broadcast();
}

void TCPServerSocket::Close(int32_t result, int32_t* pres) {
  SimpleAutoLock lock(sys_->mutex());
  delete socket_;
  socket_ = NULL;
  *pres = PP_OK;
  sys_->cond().broadcast();
}

