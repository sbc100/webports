#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

readonly LIB_ROOT=`pwd`
readonly LIB_GLIBC_COMPAT=libglibc-compat.a

CustomExtractStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  mkdir -p ${PACKAGE_NAME}
  cp -r ${LIB_ROOT}/* ${PACKAGE_NAME}
}

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
}

CustomInstallStep() {
  Remove ${NACLPORTS_LIBDIR}/${LIB_GLIBC_COMPAT}
  Remove ${NACLPORTS_INCLUDE}/glibc-compat
  install -m 644 out/${LIB_GLIBC_COMPAT} ${NACLPORTS_LIBDIR}/${LIB_GLIBC_COMPAT}
  cp -r include ${NACLPORTS_INCLUDE}/glibc-compat
}

CustomPackageInstall() {
  DefaultPreInstallStep
  CustomExtractStep
  CustomConfigureStep
  DefaultBuildStep
  CustomInstallStep
}

CustomPackageInstall
