#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

source pkg_info
source ../../build_tools/common.sh

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  MakeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/${NACL_BUILD_SUBDIR}
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/${NACL_BUILD_SUBDIR}
  echo "Directory: $(pwd)"

  # TODO(binji): turn on shared building for glibc (need -fPIC)
  local BUILD_SHARED=FALSE
  # TODO(binji): The tests don't currently build without zlib as a shared
  # library.
  local BUILD_TEST=FALSE

  CC="${NACLCC}" CXX="${NACLCXX}" cmake .. \
      -DCMAKE_TOOLCHAIN_FILE=../XCompile-nacl.txt \
      -DNACLAR=${NACLAR} \
      -DNACL_CROSS_PREFIX=${NACL_CROSS_PREFIX} \
      -DNACL_SDK_ROOT=${NACL_SDK_ROOT} \
      -DCMAKE_INSTALL_PREFIX=${NACLPORTS_PREFIX} \
      -DPHYSFS_BUILD_SHARED=${BUILD_SHARED} \
      -DPHYSFS_BUILD_TEST=${BUILD_TEST}
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  DefaultInstallStep
}


CustomPackageInstall
exit 0
