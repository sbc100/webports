/*
 * Copyright (c) 2010 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that be
 * found in the LICENSE file.
 */

#include "nacl_escape.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>


char *escape_string(const char *src, int src_len) {
  char *escaped;
  char *dst;
  int ret;

  /* Prepare workspace. */
  escaped = malloc(src_len * 2 + 1);
  assert(escaped);
  /* Escape it. */
  dst = escaped;
  for (; src_len; --src_len, ++src) {
    sprintf(dst, "%02x", *(unsigned char*)src);
    dst += 2; 
  }
  *dst = '\0';
  return escaped;
}

void unescape_string(const char *src, char **dst, int *dst_len) {
  char *unescaped;
  char *dstp;
  char tmp[3];
  int val;

  /* Prepare space. */
  unescaped = malloc(strlen(src));
  assert(unescaped);
  /* Unescape it. */
  dstp = unescaped;
  for (; *src; src += 2) {
    tmp[0] = src[0];
    tmp[1] = src[1];
    tmp[2] = 0;
    sscanf(tmp, "%x", &val);
    *dstp++ = val;
  }
  *dst = unescaped;
  *dst_len = dstp - unescaped;
}

