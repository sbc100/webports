#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-openal-soft-1.13.sh
#
# usage:  nacl-openal-soft-1.13.sh
#
# this script downloads, patches, and builds OpenAL for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/openal-soft-1.13.tar.bz2
#readonly URL=http://kcat.strangesoft.net/openal-releases/openal-soft-1.13.tar.bz2
readonly PATCH_FILE=nacl-openal-soft-1.13.patch
readonly PACKAGE_NAME=openal-soft-1.13

source ../../build_tools/common.sh

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"

  # Defaults to dynamic lib, but newlib can only link statically.
  LIB_ARG=
  if [[ ${NACL_TOOLCHAIN_ROOT} == *newlib* ]]; then
    LIB_ARG="-DLIBTYPE=STATIC"
  fi

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}/build
  cmake .. -DCMAKE_TOOLCHAIN_FILE=../XCompile-nacl.txt \
           -DNACLCC=${NACLCC} \
           -DNACLCXX=${NACLCXX} \
           -DCMAKE_INSTALL_PREFIX=${NACL_SDK_USR} \
           ${LIB_ARG}

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

