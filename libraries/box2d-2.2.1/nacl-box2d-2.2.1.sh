#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-box2d-2.2.1.sh
#
# usage:  nacl-box2d-2.2.1.sh
#
# this script downloads, patches, and builds Box2D for Native Client
#

source pkg_info
source ../../build_tools/common.sh

RunSelLdrTests() {
  if [ $OS_SUBDIR = "windows" ]; then
    echo "Not running sel_ldr tests on Windows."
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


  RunSelLdrCommand ${PACKAGE_DIR}/${PACKAGE_NAME}-build/HelloWorld/HelloWorld
}

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  export PACKAGE_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}/Box2D_v2.2.1
  ChangeDir ${PACKAGE_DIR}
  Remove ${PACKAGE_NAME}-build
  MakeDir ${PACKAGE_NAME}-build
  cd ${PACKAGE_NAME}-build
  echo "Directory: $(pwd)"

  cmake .. -DBOX2D_BUILD_EXAMPLES=OFF \
           -DCMAKE_TOOLCHAIN_FILE=../XCompile-nacl.txt \
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
  make Box2D HelloWorld -j${OS_JOBS}
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
