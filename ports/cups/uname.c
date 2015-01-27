/*
 * Copyright 2015 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <sys/utsname.h>

// Dummy implementations of the uname() method. If you want a functional
// version, link against nacl_io instead.

// TODO(sbc): Add uname() to libnacl (NaCl bug 3997).
int uname(struct utsname *buf) {
  return -1;
}
