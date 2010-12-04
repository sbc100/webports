#!/bin/bash
# Copyright (c) 2010 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that be
# found in the LICENSE file.
#

# nacl-nethack-343.sh
#
# usage:  nacl-nethack-343.sh
#
# this script downloads, patches, and builds libjpeg for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/nethack-343-src.tgz
readonly PATCH_FILE=nethack-3.4.3/nacl-nethack-3.4.3.patch
readonly PACKAGE_NAME=nethack-3.4.3

source ../common.sh


CustomBuildStep() {
  Banner "Building ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACL_SDK_USR_LIB}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACL_SDK_USR_LIB}
  export PATH=${NACL_BIN_PATH}:${PATH};
  export STRNCMPI=1
  export PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  ChangeDir ${PACKAGE_DIR}
  cp ${START_DIR}/nacl_start.c ${PACKAGE_DIR}/src
  bash sys/unix/setup.sh
  make
  make install
  Banner "Installing ${PACKAGE_NAME}"
  export PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}
  cp ${PACKAGE_DIR}/out/games/lib/nethackdir/nethack \
      ${PUBLISH_DIR}/nethack.nexe
  ChangeDir ${PACKAGE_DIR}/out/games
  rm ${PACKAGE_DIR}/out/games/lib/nethackdir/nethack
  python ${NACL_SDK_USR_LIB}/memory_filesys/simple_tar.py lib lib.sar
  cp ${PACKAGE_DIR}/out/games/lib.sar ${PUBLISH_DIR}/nethack.sar
  cp ${START_DIR}/nethack.html ${PUBLISH_DIR}
  cp ${NACL_SDK_USR_LIB}/memory_filesys/*.js ${PUBLISH_DIR}
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
