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

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/SDL_mixer-1.2.11.tar.gz
# readonly URL=http://www.libsdl.org/projects/SDL_mixer/release/SDL_mixer-1.2.11.tar.gz
readonly PATCH_FILE=nacl-SDL_mixer-1.2.11.patch
readonly PACKAGE_NAME=SDL_mixer-1.2.11

source ../../build_tools/common.sh

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACL_SDK_USR_LIB}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACL_SDK_USR_LIB}
  # Adding target usr/bin for libmikmod-config
  export PATH=${NACL_BIN_PATH}:${NACL_SDK_USR}/bin:${PATH};
  export LIBS="-lvorbisfile -lvorbis -logg -lm"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  Remove ${PACKAGE_NAME}-build
  MakeDir ${PACKAGE_NAME}-build
  cd ${PACKAGE_NAME}-build
  ../configure \
    --host=nacl \
    --disable-shared \
    --prefix=${NACL_SDK_USR} \
    --exec-prefix=${NACL_SDK_USR} \
    --libdir=${NACL_SDK_USR_LIB} \
    --oldincludedir=${NACL_SDK_USR_INCLUDE} \
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
