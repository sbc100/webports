#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}

BuildStep() {
  make -f Makefile SYSTEM=nacl-${NACL_ARCH}
}

InstallStep() {
  MakeDir ${DESTDIR_LIB}
  MakeDir ${DESTDIR_INCLUDE}
  LogExecute cp -a lib/nacl-${NACL_ARCH}/libRegal*.a ${DESTDIR_LIB}/
  if [ "${NACL_SHARED}" = 1 ]; then
    LogExecute cp -a lib/nacl-${NACL_ARCH}/libRegal*.so* ${DESTDIR_LIB}/
  fi
  LogExecute cp -r include/GL ${DESTDIR_INCLUDE}/
}
