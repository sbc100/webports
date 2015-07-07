# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXTRA_CONFIGURE_ARGS="--disable-largefile"

export getline=getline

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat -std=gnu99"
  export getline=__getline
  export LIBS+=" -lglibc-compat"
fi
