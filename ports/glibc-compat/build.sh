#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

readonly LIB_GLIBC_COMPAT=libglibc-compat.a

BUILD_DIR=${SRC_DIR}

ConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  MakeDir ${BUILD_DIR}
  LogExecute cp -rf ${START_DIR}/* ${BUILD_DIR}
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export NACL_SDK_VERSION
  ChangeDir ${SRC_DIR}
  LogExecute rm -rf out
}

InstallStep() {
  Remove ${NACLPORTS_LIBDIR}/${LIB_GLIBC_COMPAT}
  Remove ${NACLPORTS_INCLUDE}/glibc-compat
  LogExecute install -m 644 out/${LIB_GLIBC_COMPAT} ${NACLPORTS_LIBDIR}/${LIB_GLIBC_COMPAT}
  LogExecute cp -r include ${NACLPORTS_INCLUDE}/glibc-compat
}
