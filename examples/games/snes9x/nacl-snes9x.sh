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

ConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"

  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
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

  export LIBS="${LDFLAGS} \
      -lnacl-mounts -lppapi_cpp -lppapi \
      -lpthread -lstdc++"

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/unix
  cp -f ${START_DIR}/pepper.cpp .
  cp -f ${START_DIR}/nacl.h .
  cp -f ${START_DIR}/nacl.cpp .
  cp -f ${START_DIR}/event_queue.h .
  autoconf && ./configure ${CONFIG_FLAGS}
}

InstallStep(){
  BUILD_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/unix
  MakeDir ${PUBLISH_DIR}
  install ${START_DIR}/snes.html ${PUBLISH_DIR}
  install ${START_DIR}/snes.js ${PUBLISH_DIR}
  install ${START_DIR}/style.css ${PUBLISH_DIR}
  install ${START_DIR}/snes.nmf ${PUBLISH_DIR}
  install ${BUILD_DIR}/snes9x \
      ${PUBLISH_DIR}/snes_${NACL_ARCH}.nexe
}

PackageInstall
exit 0
