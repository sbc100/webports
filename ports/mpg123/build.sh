#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# TODO(binji): Use assembly
EXTRA_CONFIGURE_ARGS="--enable-static -with-cpu=generic_fpu"

if [ "${NACL_SHARED}" = "1" ]; then
  EXE_DIR=src/.libs
else
  EXE_DIR=src
fi

EXECUTABLES="${EXE_DIR}/mpg123${NACL_EXEEXT} \
  ${EXE_DIR}/out123${NACL_EXEEXT} \
  ${EXE_DIR}/mpg123-id3dump${NACL_EXEEXT} \
  ${EXE_DIR}/mpg123-strip${NACL_EXEEXT}"

if [ "${NACL_LIBC}" = "newlib" ]; then
  # Disable network support for newlib builds.
  # TODO(sbc): remove this once network syscalls land in libnacl
  EXTRA_CONFIGURE_ARGS+=" --enable-network=no"
  # sigaction is not defined by newlib.
  NACLPORTS_CPPFLAGS+=" -DDONT_CATCH_SIGNALS"
fi

NACLPORTS_LDFLAGS="${NACLPORTS_LDFLAGS} -pthread"
