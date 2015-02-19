# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  LIBS+=" -lglibc-compat"
fi

# The transtive dependencies of libxpm include nacl_io which is
# written in C++. Without this sxpm binary fails to link.
if [ "${NACL_SHARED}" != "1" ]; then
  LIBS+=" -l${NACL_CPP_LIB} -pthread"
fi

export LIBS
