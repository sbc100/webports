/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_DEV_RANDOMDEVICE_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_DEV_RANDOMDEVICE_H_

#include "../dev/Device.h"

// RandomDevice
class RandomDevice : public Device {
 public:
  RandomDevice(int (*get_random_bytes)(void *buf, size_t count, size_t *nread))
    : get_random_bytes_(get_random_bytes) {}
  virtual ~RandomDevice() {}
  int Read(off_t offset, void *buf, size_t count);
  int Write(off_t offset, const void *buf, size_t count);
 private:
  int (*get_random_bytes_)(void *buf, size_t count, size_t *nread);

  DISALLOW_COPY_AND_ASSIGN(RandomDevice);
};

#endif

