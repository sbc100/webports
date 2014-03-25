#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


BUILD_DIR=${SRC_DIR}

ConfigureStep() {
  LogExecute cp -rf ${START_DIR}/* .
  LogExecute rm -rf out
}

BuildStep() {
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export NACL_SDK_VERSION
  DefaultBuildStep
}

InstallStep() {
  local LIB=libglibc-compat.a
  MakeDir ${DESTDIR_LIB}
  Remove ${DESTDIR_INCLUDE}/glibc-compat
  MakeDir ${DESTDIR_INCLUDE}/glibc-compat
  LogExecute install -m 644 out/${LIB} ${DESTDIR_LIB}/${LIB}
  LogExecute cp -r include/* ${DESTDIR_INCLUDE}/glibc-compat
}
