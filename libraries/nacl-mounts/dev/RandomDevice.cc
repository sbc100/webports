/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "../dev/RandomDevice.h"
#include <errno.h>

int RandomDevice::Read(off_t offset, void *buf, size_t count) {
  size_t nread;
  get_random_bytes_(buf, count, &nread);
  return nread;
}

int RandomDevice::Write(off_t offset, const void *buf, size_t count) {
  return EPERM;
}

bool RandomDevice::IsReadReady() {
  return true;
}

bool RandomDevice::IsWriteReady() {
  return false;
}

bool RandomDevice::IsException() {
  return false;
}
