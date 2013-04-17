#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

source pkg_info
source ../../build_tools/common.sh

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  Remove "build-nacl"
  MakeDir "build-nacl"
  cd "build-nacl"
  echo "Directory: $(pwd)"
  if [ ${NACL_GLIBC} = "1" ] ; then
    local BUILD_SHARED=TRUE
    local BUILD_TEST=TRUE
  else
    local BUILD_SHARED=FALSE
    # TODO(binji): Figure out how to get the Newlib tests building...
    local BUILD_TEST=FALSE
  fi

  cmake ..  -DCMAKE_TOOLCHAIN_FILE=../XCompile-nacl.txt \
           -DNACLCC=${NACLCC} \
           -DNACLCXX=${NACLCXX} \
           -DNACLAR=${NACLAR} \
           -DNACL_CROSS_PREFIX=${NACL_CROSS_PREFIX} \
           -DNACL_SDK_ROOT=${NACL_SDK_ROOT} \
           -DCMAKE_INSTALL_PREFIX=${NACLPORTS_PREFIX} \
           -DPHYSFS_BUILD_SHARED=${BUILD_SHARED} \
           -DPHYSFS_BUILD_TEST=${BUILD_TEST}
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadBzipStep
  DefaultExtractBzipStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  DefaultInstallStep
  DefaultCleanUpStep
}


CustomPackageInstall
exit 0
