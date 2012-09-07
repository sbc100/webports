#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-glibc-compat-0.1.sh
#
# usage: nacl-glibc-compat-0.1.sh
#
# this script builds glibc comaptibility for Native Client 
#

readonly PACKAGE_NAME=glibc-compat-0.1

readonly LIB_ROOT=`pwd`
readonly LIB_GLIBC_COMPAT=libglibc-compat.a

source ../../build_tools/common.sh

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
  Remove ${NACL_SDK_USR_LIB}/${LIB_GLIBC_COMPAT}
  Remove ${NACL_SDK_USR_INCLUDE}/glibc-compat
  install -m 644 out/${LIB_GLIBC_COMPAT} ${NACL_SDK_USR_LIB}/${LIB_GLIBC_COMPAT}
  cp -r include ${NACL_SDK_USR_INCLUDE}/glibc-compat
}

CustomPackageInstall() {
  DefaultPreInstallStep
  CustomExtractStep
  CustomConfigureStep
  DefaultBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
