#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# TODO(binji): Use assembly
EXTRA_CONFIGURE_ARGS="--enable-static -with-cpu=generic_fpu"

if [ "${NACL_LIBC}" != "glibc" ]; then
  # Disable network support for newlib builds.
  # TODO(sbc): remove this once network syscalls land in libnacl
  EXTRA_CONFIGURE_ARGS+=" --enable-network=no"
fi

NACLPORTS_LDFLAGS="${NACLPORTS_LDFLAGS} -static"

BuildStep() {
  export PATH=${NACL_BIN_PATH}:${PATH}

  ChangeDir src/libmpg123
  LogExecute make clean
  LogExecute make -j${OS_JOBS}

  Banner "Building Tests"
  local tests="tests/seek_accuracy${NACL_EXEEXT} tests/seek_whence${NACL_EXEEXT} tests/text${NACL_EXEEXT}"

  ChangeDir ..
  LogExecute make clean
  LogExecute make -j${OS_JOBS} ${tests}
}

InstallStep() {
  ChangeDir src/libmpg123
  DefaultInstallStep
}
