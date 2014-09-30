# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="glib/gtester${NACL_EXEEXT}"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
fi

ConfigureStep() {
  SetupCrossEnvironment
  if [ "${NACL_LIBC}" = "newlib" ]; then
    export LIBS+=" -lglibc-compat"
  fi

  cp ${SRC_DIR}/nacl.cache nacl.cache.tmp

  LogExecute ${SRC_DIR}/configure \
    --host=nacl \
    --prefix=${PREFIX} \
    --${NACL_OPTION}-mmx \
    --${NACL_OPTION}-sse \
    --${NACL_OPTION}-sse2 \
    --${NACL_OPTION}-asm \
    --cache-file=nacl.cache.tmp
}
