// Copyright (c) 2012 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "net/TcpSocket.h"

#include <assert.h>
#include <string.h>
#include "../net/SocketSubSystem.h"
#include "ppapi/c/pp_errors.h"
#include "ppapi/cpp/module.h"
#include "ppapi/cpp/private/net_address_private.h"
#include "../util/DebugPrint.h"
#include "../util/PthreadHelpers.h"

TCPSocket::TCPSocket(SocketSubSystem* sys, int oflag)
  : ref_(1), oflag_(oflag), factory_(this), socket_(NULL),
    read_buf_(kBufSize), write_sent_(false), sys_(sys) {
}

TCPSocket::~TCPSocket() {
  assert(!socket_);
  assert(!ref_);
}

void TCPSocket::addref() {
  ++ref_;
}

void TCPSocket::release() {
  if (!--ref_)
    delete this;
}

bool TCPSocket::connect(const char* host, uint16_t port) {
  SimpleAutoLock lock(sys_->mutex());
  int32_t result = PP_OK_COMPLETIONPENDING;
  pp::Module::Get()->core()->CallOnMainThread(0,
      factory_.NewCallback(&TCPSocket::Connect, host, port, &result));
  while (result == PP_OK_COMPLETIONPENDING) {
    sys_->cond().wait(sys_->mutex());
  }
  return result == PP_OK;
}

bool TCPSocket::acceptFrom(PP_Resource resource) {
  SimpleAutoLock lock(sys_->mutex());
  int32_t result = PP_OK_COMPLETIONPENDING;
  pp::Module::Get()->core()->CallOnMainThread(0,
      factory_.NewCallback(&TCPSocket::Accept, resource, &result));
  while (result == PP_OK_COMPLETIONPENDING) {
    sys_->cond().wait(sys_->mutex());
  }
  return result == PP_OK;
}

void TCPSocket::close() {
  SimpleAutoLock lock(sys_->mutex());
  if (socket_) {
    int32_t result = PP_OK_COMPLETIONPENDING;
    pp::Module::Get()->core()->CallOnMainThread(0,
        factory_.NewCallback(&TCPSocket::Close, &result));
    while (result == PP_OK_COMPLETIONPENDING) {
      sys_->cond().wait(sys_->mutex());
    }
  }
}

int TCPSocket::read(char* buf, size_t count, size_t* nread) {
  SimpleAutoLock lock(sys_->mutex());
  if (!is_open())
    return EIO;

  if (is_block()) {
    while (in_buf_.empty() && is_open())
      sys_->cond().wait(sys_->mutex());
  }

  *nread = 0;
  while (*nread < count) {
    if (in_buf_.empty())
      break;

    buf[(*nread)++] = in_buf_.front();
    in_buf_.pop_front();
  }

  if (*nread == 0) {
    if (!is_open()) {
      return 0;
    } else {
      *nread = -1;
      return EAGAIN;
    }
  }

  return 0;
}

int TCPSocket::write(const char* buf, size_t count, size_t* nwrote) {
  SimpleAutoLock lock(sys_->mutex());
  if (!is_open())
    return EIO;

  out_buf_.insert(out_buf_.end(), buf, buf + count);
  if (is_block()) {
    int32_t result = PP_OK_COMPLETIONPENDING;
    pp::Module::Get()->core()->CallOnMainThread(0,
        factory_.NewCallback(&TCPSocket::Write, &result));
    while (result == PP_OK_COMPLETIONPENDING)
      sys_->cond().wait(sys_->mutex());
    if ((size_t)result != count) {
      *nwrote = -1;
      return EIO;
    } else {
      *nwrote = count;
      return 0;
    }
  } else {
    if (!write_sent_) {
      write_sent_ = true;
      pp::Module::Get()->core()->CallOnMainThread(0,
        factory_.NewCallback(&TCPSocket::Write,
          reinterpret_cast<int32_t*>(NULL)));
    }
    *nwrote = count;
    return 0;
  }
}

int TCPSocket::fcntl(int cmd, va_list ap) {
  if (cmd == F_GETFL) {
    return oflag_;
  } else if (cmd == F_SETFL) {
    oflag_ = va_arg(ap, long);
    return 0;
  } else {
    return -1;
  }
}

bool TCPSocket::is_read_ready() {
  return !is_open() || !in_buf_.empty();
}

bool TCPSocket::is_write_ready() {
  return !is_open() || out_buf_.size() < kBufSize;
}

bool TCPSocket::is_exception() {
  return !is_open();
}

void TCPSocket::Connect(int32_t result, const char* host, uint16_t port,
                        int32_t* pres) {
  SimpleAutoLock lock(sys_->mutex());
  assert(!socket_);
  socket_ = new pp::TCPSocketPrivate(sys_->instance());
  *pres = socket_->Connect(host, port,
      factory_.NewCallback(&TCPSocket::OnConnect, pres));
  if (*pres != PP_OK_COMPLETIONPENDING) {
    sys_->cond().broadcast();
  }
}

struct GetAddressResult {
  int result;
  struct sockaddr* addr;
};

void TCPSocket::getAddress(struct sockaddr* addr) {
  struct GetAddressResult r = { PP_OK_COMPLETIONPENDING, addr };
  SimpleAutoLock lock(sys_->mutex());
  pp::Module::Get()->core()->CallOnMainThread(0,
      factory_.NewCallback(&TCPSocket::GetAddress,
      reinterpret_cast<int32_t*>(&r)));
  while (r.result == PP_OK_COMPLETIONPENDING) {
    sys_->cond().wait(sys_->mutex());
  }
}

void TCPSocket::GetAddress(int32_t result, int32_t* pres) {
  SimpleAutoLock lock(sys_->mutex());
  struct GetAddressResult* r = reinterpret_cast<struct GetAddressResult*>(pres);
  struct sockaddr* addr = r->addr;
  struct sockaddr_in* iaddr = (struct sockaddr_in*) addr;
  struct sockaddr_in6* iaddr6 = (struct sockaddr_in6*) addr;
  PP_NetAddress_Private netaddr;
  socket_->GetRemoteAddress(&netaddr);
  PP_NetAddressFamily_Private family =
    pp::NetAddressPrivate::GetFamily(netaddr);
  if (family == PP_NETADDRESSFAMILY_IPV4) {
    iaddr->sin_family = AF_INET;
  } else if (family == PP_NETADDRESSFAMILY_IPV6) {
    iaddr->sin_family = AF_INET6;
  } else {
    iaddr->sin_family = AF_UNSPEC;
    r->result = PP_ERROR_FAILED;
    return;
  }
  iaddr6->sin6_port = pp::NetAddressPrivate::GetPort(netaddr);
  if (family == PP_NETADDRESSFAMILY_IPV6) {
    pp::NetAddressPrivate::GetAddress(
        netaddr, &iaddr6->sin6_addr, sizeof(in6_addr));
  } else {
    pp::NetAddressPrivate::GetAddress(
        netaddr, &iaddr->sin_addr, sizeof(in_addr));
  }
  r->result = PP_OK;
  sys_->cond().broadcast();
}

void TCPSocket::OnConnect(int32_t result, int32_t* pres) {
  SimpleAutoLock lock(sys_->mutex());
  if (result == PP_OK) {
    Read(PP_OK, NULL);
  } else {
    delete socket_;
    socket_ = NULL;
  }
  *pres = result;
  sys_->cond().broadcast();
}

void TCPSocket::Read(int32_t result, int32_t* pres) {
  SimpleAutoLock lock(sys_->mutex());
  if (!is_open())
    return;

  result = socket_->Read(&read_buf_[0], read_buf_.size(),
      factory_.NewCallback(&TCPSocket::OnRead, pres));
  if (result != PP_OK_COMPLETIONPENDING) {
    delete socket_;
    socket_ = NULL;
    if (pres)
      *pres = result;
    sys_->cond().broadcast();
  }
}

void TCPSocket::OnRead(int32_t result, int32_t* pres) {
  SimpleAutoLock lock(sys_->mutex());
  if (!is_open())
    return;

  if (result > 0) {
    in_buf_.insert(in_buf_.end(), &read_buf_[0], &read_buf_[0]+result);
    Read(PP_OK, NULL);
  } else {
    delete socket_;
    socket_ = NULL;
  }
  if (pres)
    *pres = result;
  sys_->cond().broadcast();
}

void TCPSocket::Write(int32_t result, int32_t* pres) {
  SimpleAutoLock lock(sys_->mutex());
  if (!is_open())
    return;

  if (write_buf_.size()) {
    // Previous write operation is in progress.
    pp::Module::Get()->core()->CallOnMainThread(1,
        factory_.NewCallback(&TCPSocket::Write, &result));
    return;
  }
  assert(out_buf_.size());
  write_buf_.swap(out_buf_);
  result = socket_->Write(&write_buf_[0], write_buf_.size(),
      factory_.NewCallback(&TCPSocket::OnWrite, pres));
  if (result != PP_OK_COMPLETIONPENDING) {
    dbgprintf("TCPSocket::Write: failed %d %d\n", result, write_buf_.size());
    delete socket_;
    socket_ = NULL;
    if (pres)
      *pres = result;
    sys_->cond().broadcast();
  }
  write_sent_ = false;
}

void TCPSocket::OnWrite(int32_t result, int32_t* pres) {
  SimpleAutoLock lock(sys_->mutex());
  if (!is_open())
    return;

  if (result < 0 || (size_t)result > write_buf_.size()) {
    // Write error.
    dbgprintf("TCPSocket::OnWrite: close socket\n");
    delete socket_;
    socket_ = NULL;
  } else if ((size_t)result < write_buf_.size()) {
    // Partial write. Insert remaining bytes at the beginning of out_buf_.
    out_buf_.insert(out_buf_.begin(), &write_buf_[result], &*write_buf_.end());
  }
  if (pres)
    *pres = result;
  write_buf_.clear();
  sys_->cond().broadcast();
}

void TCPSocket::Close(int32_t result, int32_t* pres) {
  SimpleAutoLock lock(sys_->mutex());
  delete socket_;
  socket_ = NULL;
  if (pres)
    *pres = PP_OK;
  sys_->cond().broadcast();
}

bool TCPSocket::Accept(int32_t result, PP_Resource resource, int32_t* pres) {
  SimpleAutoLock lock(sys_->mutex());
  assert(!socket_);
  socket_ = new pp::TCPSocketPrivate(pp::PassRef(), resource);
  Read(PP_OK, NULL);
  *pres = PP_OK;
  sys_->cond().broadcast();
  return true;
}

