/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_DEV_DEVICE_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_DEV_DEVICE_H_

#include <sys/types.h>
#include "../util/macros.h"

// Device
class Device {
 public:
  Device() {}
  virtual ~Device() {}
  virtual int Read(off_t offset, void *buf, size_t count) = 0;
  virtual int Write(off_t offset, const void *buf, size_t count) = 0;
  virtual bool IsReadReady() = 0;
  virtual bool IsWriteReady() = 0;
  virtual bool IsException() = 0;
};

#endif

