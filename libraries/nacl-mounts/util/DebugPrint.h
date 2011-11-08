/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <stdio.h>
#include <stdarg.h>
#include <sys/types.h>

extern "C" {
  ssize_t __real_write(int fd, const void *buf, size_t count);
}

static int dbgprintf(const char* format, ...) {
  const int buf_size = 1000;
  char buf[buf_size];
  va_list args;
  va_start(args, format);
  ssize_t r = vsnprintf(buf, buf_size, format, args);
  if (r > 0)
    __real_write(2, buf, r);
  va_end(args);
  return r;
}
