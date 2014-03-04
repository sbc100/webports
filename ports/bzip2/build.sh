#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}

ConfigureStep() {
  return
}

BuildStep() {
  make clean
  make CC="${NACLCC}" AR="${NACLAR}" RANLIB="${NACLRANLIB}" -j${OS_JOBS} libbz2.a
  if [ ${NACL_GLIBC} = 1 ]; then
    LogExecute make -f Makefile-libbz2_so clean
    LogExecute make -f Makefile-libbz2_so CC="${NACLCC}" AR="${NACLAR}" \
        RANLIB="${NACLRANLIB}" -j${OS_JOBS}
  fi
}

InstallStep() {
  # Don't rely on make install, as it implicitly builds executables
  # that need things not available in newlib.
  LogExecute mkdir -p ${NACLPORTS_PREFIX}/include
  LogExecute cp -f bzlib.h ${NACLPORTS_PREFIX}/include
  LogExecute chmod a+r ${NACLPORTS_PREFIX}/include/bzlib.h

  LogExecute mkdir -p ${NACLPORTS_PREFIX}/lib
  LogExecute cp -f libbz2.a ${NACLPORTS_PREFIX}/lib
  if [ -f libbz2.so.1.0 ]; then
    LogExecute ln -s libbz2.so.1.0 libbz2.so
    LogExecute cp -af libbz2.so* ${NACLPORTS_PREFIX}/lib
  fi
  LogExecute chmod a+r ${NACLPORTS_PREFIX}/lib/libbz2.*
}
