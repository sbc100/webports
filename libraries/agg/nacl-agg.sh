#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-agg-2.5.sh
#
# usage:  nacl-agg-2.5.sh
#
# this script downloads, patches, and builds agg for Native Client
#

source pkg_info
source ../../build_tools/common.sh


CustomBuildStep() {
  cd ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  local cflags="${NACLPORTS_CFLAGS}"
  if [ ${NACL_ARCH} != "pnacl" ] ; then
    cflags="${cflags} -O3 -mfpmath=sse -msse -fomit-frame-pointer"
  fi
  AGGCXXFLAGS="${cflags}" make NACLCXX=${NACLCXX} NACLCC=${NACLCC} NACLAR=${NACLAR}
}


CustomInstallStep() {
  # copy libs and headers manually
  ChangeDir ${NACLPORTS_INCLUDE}
  Remove ${PACKAGE_NAME}
  MakeDir ${PACKAGE_NAME}
  readonly THIS_PACKAGE_PATH=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  cp -R ${THIS_PACKAGE_PATH}/include/*.h ${PACKAGE_NAME}/
  cp ${THIS_PACKAGE_PATH}/font_freetype/*.h ${PACKAGE_NAME}/
  ChangeDir ${NACLPORTS_LIBDIR}
  cp ${THIS_PACKAGE_PATH}/src/libagg.a .
  cp ${THIS_PACKAGE_PATH}/font_freetype/libaggfontfreetype.a .
  DefaultTouchStep
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}


CustomPackageInstall
exit 0
