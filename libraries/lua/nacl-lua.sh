#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-lua-5.1.4.sh
#
# usage:  nacl-lua-5.1.4.sh
#
# this script downloads, patches, and builds lua for Native Client 
#

source pkg_info
source ../../build_tools/common.sh


CustomBuildStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  make "CC=${NACLCC}" "PLAT=generic" "INSTALL_TOP=${NACLPORTS_PREFIX}" clean
  PATH=${NACL_BIN_PATH}:${PATH} \
  make "CC=${NACLCC}" "PLAT=generic" "INSTALL_TOP=${NACLPORTS_PREFIX}" "MYLIBS=-lnosys"
  # TODO: side-by-side install
  make "CC=${NACLCC}" "PLAT=generic" "INSTALL_TOP=${NACLPORTS_PREFIX}" install
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomBuildStep
  DefaultCleanUpStep
}


CustomPackageInstall
exit 0
