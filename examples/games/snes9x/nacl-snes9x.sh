#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-snes-1.53.sh
#
# Usage:  nacl-snes-1.53.sh
#
# This script downloads, patches, and builds an snes9x-based SNES emulator for
# Native Client.

source pkg_info
PACKAGE_DIR=${PACKAGE_NAME}-src
source ../../../build_tools/common.sh

DOSBOX_EXAMPLE_DIR=${NACL_SRC}/examples/games/snes9x-1.53
EXECUTABLES=snes9x

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"

  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export CXXFLAGS="${NACLPORTS_CFLAGS} -I${NACL_SDK_ROOT}/include"
  export LDFLAGS="${NACLPORTS_LDFLAGS}"
  if [ ${NACL_ARCH} = "pnacl" ] ; then
    export CXXFLAGS="${NACLPORTS_CFLAGS} -I${NACL_SDK_ROOT}/include -O3 -g"
    export LDFLAGS="${NACLPORTS_LDFLAGS} -O0 -static"
  fi
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}

  CONFIG_FLAGS="--host=nacl \
      --prefix=${NACLPORTS_PREFIX} \
      --exec-prefix=${NACLPORTS_PREFIX} \
      --libdir=${NACLPORTS_LIBDIR} \
      --oldincludedir=${NACLPORTS_INCLUDE} \
      --disable-gamepad \
      --disable-gzip \
      --disable-zip \
      --disable-jma \
      --disable-screenshot \
      --disable-netplay \
      --without-x \
      --enable-sound"

  export LIBS="-L${NACLPORTS_LIBDIR} \
      -lnacl-mounts -lppapi_cpp -lppapi \
      -lpthread -lstdc++"

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/unix
  cp -f ${START_DIR}/pepper.cpp .
  cp -f ${START_DIR}/nacl.h .
  cp -f ${START_DIR}/nacl.cpp .
  cp -f ${START_DIR}/event_queue.h .
  autoconf && ./configure ${CONFIG_FLAGS}
}

CustomInstallStep(){
  BUILD_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/unix
  PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}
  install ${START_DIR}/snes.html ${PUBLISH_DIR}
  install ${START_DIR}/snes.js ${PUBLISH_DIR}
  install ${START_DIR}/style.css ${PUBLISH_DIR}
  install ${START_DIR}/snes.nmf ${PUBLISH_DIR}
  install ${BUILD_DIR}/snes9x \
      ${PUBLISH_DIR}/snes_x86_${NACL_ARCH}.nexe
  DefaultTouchStep
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadBzipStep
  DefaultExtractBzipStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  DefaultTranslateStep
  DefaultValidateStep
  CustomInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
