/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_DEV_NULLDEVICE_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_DEV_NULLDEVICE_H_

#include "../dev/Device.h"

// NullDevice
class NullDevice : public Device {
 public:
  NullDevice() {}
  ~NullDevice() {}
  int Read(off_t offset, void *buf, size_t count);
  int Write(off_t offset, const void *buf, size_t count);
 private:
  DISALLOW_COPY_AND_ASSIGN(NullDevice);
};

#endif

