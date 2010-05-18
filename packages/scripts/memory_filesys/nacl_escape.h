/*
 * Copyright (c) 2010 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that be
 * found in the LICENSE file.
 */

#ifndef _nacl_escape_h
#define _nacl_escape_h

extern char *escape_string(const char *src, int src_len);
extern void unescape_string(const char *src, char **dst, int *dst_len);

#endif
