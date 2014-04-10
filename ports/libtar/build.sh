#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

NACLPORTS_CPPFLAGS+=" -DMAXPATHLEN=512 -DHAVE_STDARG_H"
NACLPORTS_CPPFLAGS+=" -Dcompat_makedev\(a,b\)"
if [ "${NACL_SHARED}" = "1" ]; then
  NACLPORTS_CFLAGS+=" -fPIC"
fi
