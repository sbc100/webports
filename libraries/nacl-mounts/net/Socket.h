// Copyright (c) 2012 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_SOCKET_H
#define PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_SOCKET_H

#include <errno.h>
#include <fcntl.h>
#include <nacl-mounts/base/nacl_stat.h>
#include <stdarg.h>
#include <string.h>
#include <sys/dir.h>
#include <sys/types.h>
#include <unistd.h>

class Socket {
 public:
  virtual ~Socket() {}

  virtual void addref() = 0;
  virtual void release() = 0;

  virtual void close() = 0;
  virtual int read(char* buf, size_t count, size_t* nread) = 0;
  virtual int write(const char* buf, size_t count, size_t* nwrote) = 0;
  virtual int seek(nacl_abi_off_t offset, int whence,
                   nacl_abi_off_t* new_offset) {
    return ESPIPE;
  }
  virtual int fstat(nacl_abi_stat* out) {
    memset(out, 0, sizeof(nacl_abi_stat));
    return 0;
  }

  virtual int fcntl(int cmd,  va_list ap) {
    errno = EINVAL;
    return -1;
  }

  virtual int ioctl(int request,  va_list ap) {
    errno = EINVAL;
    return -1;
  }

  virtual bool is_read_ready() {
    return true;
  }
  virtual bool is_write_ready() {
    return true;
  }
  virtual bool is_exception() {
    return false;
  }
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_SOCKET_H

