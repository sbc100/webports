/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <assert.h>
#include <nacl-mounts/net/newlib_compat.h>
#ifndef __GLIBC__

uint16_t htons(uint16_t v) {
  assert(0);
}

uint16_t ntohs(uint16_t v) {
  assert(0);
}

const char*
inet_ntop(int af, const void *src, char *dst, socklen_t cnt) {
  assert(0);
}

int inet_pton(int af, const char* src, void* dst) {
  assert(0);
}

#endif

