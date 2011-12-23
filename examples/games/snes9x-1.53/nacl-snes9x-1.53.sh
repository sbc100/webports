#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-snes-1.53.sh
#
# Usage:  nacl-snes-1.53.sh
#
# This script downloads, patches, and builds an snes9x-based SNES emulator for
# Native Client.

readonly URL='http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/snes9x-1.53-src.tar.bz2'
#readonly URL='https://sites.google.com/site/bearoso/snes9x/snes9x-1.53-src.tar.bz2?attredirects=0&d=1'
readonly PATCH_FILE=nacl-snes-1.53.patch
PACKAGE_NAME=snes9x-1.53

source ../../../build_tools/common.sh

DOSBOX_EXAMPLE_DIR=${NACL_SRC}/examples/games/snes9x-1.53

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"

  if [ "${NACL_GLIBC}" = "1" ]; then
    echo "Only linker wrapping for newlib is supported"
    exit -1
  fi

  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACL_SDK_USR_LIB}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACL_SDK_USR_LIB}

  CONFIG_FLAGS="--host=nacl \
      --prefix=${NACL_SDK_USR} \
      --exec-prefix=${NACL_SDK_USR} \
      --libdir=${NACL_SDK_USR_LIB} \
      --oldincludedir=${NACL_SDK_USR_INCLUDE} \
      --disable-gamepad \
      --disable-gzip \
      --disable-zip \
      --disable-jma \
      --disable-screenshot \
      --disable-netplay \
      --without-x \
      --enable-sound"

  export LIBS="-L${NACL_SDK_USR_LIB} \
      -lnacl-mounts -lppapi_cpp -lppapi \
      -lpthread -lstdc++"

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}-src/unix
  autoconf && ./configure ${CONFIG_FLAGS}
}

CustomInstallStep(){
  BUILD_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}-src/unix
  PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}
  install ${START_DIR}/snes.html ${PUBLISH_DIR}
  install ${START_DIR}/snes.js ${PUBLISH_DIR}
  install ${START_DIR}/style.css ${PUBLISH_DIR}
  install ${START_DIR}/snes.nmf ${PUBLISH_DIR}
  install ${BUILD_DIR}/snes9x \
      ${PUBLISH_DIR}/snes_x86_${NACL_PACKAGES_BITSIZE}.nexe
  DefaultTouchStep
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadBzipStep
  DefaultExtractBzipStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
