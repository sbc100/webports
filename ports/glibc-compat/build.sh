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
  export NACL_SDK_ROOT
  DefaultBuildStep
}

InstallStep() {
  local LIB=libglibc-compat.a
  INCDIR=${DESTDIR_INCLUDE}/glibc-compat
  MakeDir ${DESTDIR_LIB}
  Remove ${INCDIR}
  MakeDir ${INCDIR}
  LogExecute install -m 644 out/${LIB} ${DESTDIR_LIB}/${LIB}
  LogExecute cp include/*.h ${DESTDIR_INCLUDE}/glibc-compat
  for dir in sys arpa machine netinet netinet6; do
    MakeDir ${INCDIR}/${dir}
    LogExecute install -m 644 include/${dir}/*.h ${INCDIR}/${dir}/
  done
}
