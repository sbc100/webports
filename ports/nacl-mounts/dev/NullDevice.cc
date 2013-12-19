/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "../dev/NullDevice.h"
#include <cstring>

int NullDevice::Read(off_t offset, void *buf, size_t count) {
  return 0;
}

int NullDevice::Write(off_t offset, const void *buf, size_t count) {
  return count;
}

bool NullDevice::IsReadReady() {
  return true;
}

bool NullDevice::IsWriteReady() {
  return true;
}

bool NullDevice::IsException() {
  return false;
}
