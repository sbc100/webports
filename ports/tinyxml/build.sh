#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}

BuildStep() {
  ChangeDir ${BUILD_DIR}
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export LD=${NACLLD}
  export RANLIB=${NACLRANLIB}
  make clean
  make OUTPUT=libtinyxml.a
}

InstallStep() {
  # copy libs and headers manually
  Remove ${NACLPORTS_INCLUDE}/${PACKAGE_NAME}
  MakeDir ${NACLPORTS_INCLUDE}/${PACKAGE_NAME}
  LogExecute cp ${SRC_DIR}/*.h ${NACLPORTS_INCLUDE}/${PACKAGE_NAME}
  LogExecute cp ${SRC_DIR}/*.a ${NACLPORTS_LIBDIR}
}
