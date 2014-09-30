# Copyright 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

if [ "${NACL_SHARED}" = "1" ]; then
  EXECUTABLES=".libs/mp4tags${NACL_EXEEXT} .libs/mp4info${NACL_EXEEXT}"
else
  EXECUTABLES="mp4tags${NACL_EXEEXT} mp4info${NACL_EXEEXT}"
fi

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  export LIBS="-lglibc-compat"
fi
