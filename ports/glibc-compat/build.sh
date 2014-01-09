#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

readonly LIB_GLIBC_COMPAT=libglibc-compat.a

ExtractStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  MakeDir ${PACKAGE_NAME}
  LogExecute cp -rf ${START_DIR}/* ${PACKAGE_NAME}
}

ConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export NACL_SDK_VERSION
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  LogExecute rm -rf out
}

InstallStep() {
  Remove ${NACLPORTS_LIBDIR}/${LIB_GLIBC_COMPAT}
  Remove ${NACLPORTS_INCLUDE}/glibc-compat
  LogExecute install -m 644 out/${LIB_GLIBC_COMPAT} ${NACLPORTS_LIBDIR}/${LIB_GLIBC_COMPAT}
  LogExecute cp -r include ${NACLPORTS_INCLUDE}/glibc-compat
}

PackageInstall
exit 0
