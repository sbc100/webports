#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-SDL_mixer-1.2.11.sh
#
# usage:  nacl-SDL_mixer-1.2.11.sh
#
# this script downloads, patches, and builds SDL_mixer for Native Client
#

source pkg_info
source ../../build_tools/common.sh
set -x

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  # Adding target usr/bin for libmikmod-config
  export PATH=${NACL_BIN_PATH}:${NACLPORTS_PREFIX}/bin:${PATH};
  export LIBS="-lvorbisfile -lvorbis -logg -lm"
  MakeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}/${NACL_BUILD_SUBDIR}
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}/${NACL_BUILD_SUBDIR}
  ../configure \
    --host=nacl \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    --oldincludedir=${NACLPORTS_INCLUDE} \
    --${NACL_OPTION}-mmx \
    --${NACL_OPTION}-sse \
    --${NACL_OPTION}-sse2 \
    --${NACL_OPTION}-asm \
    --with-x=no \
    --disable-music-flac \
    --disable-music-mp3
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  DefaultInstallStep
  DefaultCleanUpStep
}


CustomPackageInstall
exit 0
