#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-bzip2-1.0.6.sh
#
# usage:  nacl-bzip2-1.0.6.sh
#
# this script downloads, patches, and builds bzip2 for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/bzip2-1.0.6.tar.gz
# readonly URL=http://bzip.org/1.0.6/bzip2-1.0.6.tar.gz
readonly PATCH_FILE=
readonly PACKAGE_NAME=bzip2-1.0.6

source ../../build_tools/common.sh

CustomConfigureStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
}

CustomBuildStep() {
  make clean
  make CC=${NACLCC} AR=${NACLAR} RANLIB=${NACLRANLIB} -j${OS_JOBS} libbz2.a
}

CustomInstallStep() {
  # assumes pwd has makefile
  make PREFIX=${NACL_SDK_USR} install
  DefaultTouchStep
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  # bzip2 doesn't need patching, so no patch step
  CustomConfigureStep
  CustomBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}


CustomPackageInstall
exit 0
