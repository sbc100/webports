#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-nethack-343.sh
#
# usage:  nacl-nethack-343.sh
#
# this script downloads, patches, and builds nethack for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/nethack-343-src.tgz
readonly PATCH_FILE=nethack-3.4.3/nacl-nethack-3.4.3.patch
readonly PACKAGE_NAME=nethack-3.4.3

source ../../../build_tools/common.sh


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
  cp ${START_DIR}/nethack_pepper.cc ${PACKAGE_DIR}/src
  bash sys/unix/setup.sh
  make
  make install
  Banner "Installing ${PACKAGE_NAME}"
  export PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}
  readonly ASSEMBLY_DIR="${PUBLISH_DIR}/nethack"
  MakeDir ${ASSEMBLY_DIR}
  cp ${PACKAGE_DIR}/out/games/lib/nethackdir/nethack \
      ${ASSEMBLY_DIR}/nethack_x86-${NACL_PACKAGES_BITSIZE:-"32"}.nexe
  ChangeDir ${PACKAGE_DIR}/out/games
  rm ${PACKAGE_DIR}/out/games/lib/nethackdir/nethack
  python ${NACL_SDK_USR_LIB}/nacl-mounts/util/simple_tar.py lib lib.sar
  cp ${PACKAGE_DIR}/out/games/lib.sar ${ASSEMBLY_DIR}/nethack.sar
  cp ${START_DIR}/nethack.html ${ASSEMBLY_DIR}
  cp ${START_DIR}/nethack.nmf ${ASSEMBLY_DIR}
  cp ${NACL_SDK_USR_LIB}/nacl-mounts/*.js ${ASSEMBLY_DIR}
  cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
  ChangeDir ${PUBLISH_DIR}
  zip -r nethack-3.4.3.zip nethack
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomBuildStep
  DefaultTouchStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
