#!/bin/bash
# Copyright (c) 2010 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that be
# found in the LICENSE file.
#

# nacl-FreeImage-3.14.1.sh
#
# usage:  nacl-FreeImage-3.14.1.sh
#
# This script downloads, patches, and builds FreeImage for Native Client
# See http://freeimage.sourceforge.net/ for more details.
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/FreeImage3141.zip
#readonly URL=http://downloads.sourceforge.net/freeimage/FreeImage3141.zip
readonly PATCH_FILE=FreeImage-3.14.1/nacl-FreeImage-3.14.1.patch
readonly PACKAGE_BASE_NAME=FreeImage
readonly PACKAGE_NAME=${PACKAGE_BASE_NAME}-3.14.1

source ../common.sh

CustomPreInstallStep() {
  DefaultPreInstallStep
  Remove ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_BASE_NAME}
}

CustomDownloadStep() {
  cd ${NACL_PACKAGES_TARBALLS}
  # If matching tarball already exists, don't download again
  if ! Check ; then
    Fetch ${URL} ${PACKAGE_NAME}.zip
    if ! Check ; then
       Banner "${PACKAGE_NAME} failed checksum!"
       exit -1
    fi
  fi
}

CustomExtractStep() {
  Banner "Unzipping ${PACKAGE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  Remove ${PACKAGE_NAME}
  unzip ${NACL_PACKAGES_TARBALLS}/${PACKAGE_NAME}.zip
}

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PATH=${NACL_BIN_PATH}:${PATH};
  export INCDIR=${NACL_SDK_USR_INCLUDE}
  export INSTALLDIR=${NACL_SDK_USR_LIB}
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_BASE_NAME}
}

CustomBuildStep() {
  # assumes pwd has makefile
  make OS=nacl clean
  make OS=nacl -j4
}

CustomInstallStep() {
  # assumes pwd has makefile
  make OS=nacl install
}

CustomPackageInstall() {
   CustomPreInstallStep
   CustomDownloadStep
   CustomExtractStep
   DefaultPatchStep
   CustomConfigureStep
   CustomBuildStep
   CustomInstallStep
   DefaultCleanUpStep
}

CustomPackageInstall
exit 0
