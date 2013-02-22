#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-yajl.sh
#
# usage:  nacl-yajl.sh
#
# this script downloads, patches, and builds yajl for Native Client
#

source pkg_info
source ../../build_tools/common.sh

RunSelLdrTests() {
  if [ $OS_SUBDIR = "windows" ]; then
    echo "Not running sel_ldr tests on Windows."
    return
  fi

  if [ $NACL_ARCH = "arm" ]; then
    echo "Not running sel_ldr tests on ARM."
    return
  fi

  if [ ! -e ${NACL_IRT} ]; then
    echo "WARNING: Missing IRT binary. Not running sel_ldr-based tests."
    return
  fi

  if [ ${NACL_ARCH} = "pnacl" ]; then
    echo "FIXME: Not running sel_ldr-based tests with PNaCl."
    return
  fi

  local script=${PACKAGE_DIR}/${PACKAGE_NAME}-build/yajl_test.sh
  local nexe=${PACKAGE_DIR}/${PACKAGE_NAME}-build/test/yajl_test

  WriteSelLdrScript ${script} ${nexe}
  cd ${PACKAGE_DIR}/test && ./run_tests.sh ${script}
}


CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  export PACKAGE_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}/yajl-2.0.4
  ChangeDir ${PACKAGE_DIR}
  Remove ${PACKAGE_NAME}-build
  MakeDir ${PACKAGE_NAME}-build
  cd ${PACKAGE_NAME}-build
  echo "Directory: $(pwd)"

  cmake .. -DCMAKE_TOOLCHAIN_FILE=../XCompile-nacl.txt \
           -DBUILD_SHARED=${NACL_GLIBC} \
           -DNACLCC=${NACLCC} \
           -DNACLCXX=${NACLCXX} \
           -DNACLAR=${NACLAR} \
           -DNACL_CROSS_PREFIX=${NACL_CROSS_PREFIX} \
           -DNACL_SDK_ROOT=${NACL_SDK_ROOT} \
           -DCMAKE_INSTALL_PREFIX=${NACLPORTS_PREFIX}
}


CustomBuildStep() {
  Banner "Build ${PACKAGE_NAME}"
  echo "Directory: $(pwd)"
  make clean
  make all -j${OS_JOBS}
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadZipStep
  DefaultExtractZipStep
  DefaultPatchStep
  CustomConfigureStep
  CustomBuildStep
  DefaultInstallStep
  DefaultCleanUpStep
  RunSelLdrTests
}


CustomPackageInstall
exit 0
