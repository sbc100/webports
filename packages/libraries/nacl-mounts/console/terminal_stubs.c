/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <stdio.h>


// Provide an implementation of _srget_r (newlib specific) in case its no there
// to be wrapped.
int __real___srget_r(struct _reent *ptr, register FILE *fp) {
  return 0;
}
