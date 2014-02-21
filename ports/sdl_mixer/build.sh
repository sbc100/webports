#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

CONFIG_SUB=build-scripts/config.sub

# TODO: Remove when this is fixed.
# https://code.google.com/p/nativeclient/issues/detail?id=3598
if [ "$NACL_GLIBC" = "1" ]; then
  export NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS//-O2/}"
fi

ConfigureStep() {
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export CFLAGS=${NACLPORTS_CFLAGS}
  export CXXFLAGS=${NACLPORTS_CXXFLAGS}
  export CPPFLAGS=${NACLPORTS_CPPFLAGS}
  export LDFLAGS=${NACLPORTS_LDFLAGS}
  # Adding target usr/bin for libmikmod-config
  export PATH=${NACL_BIN_PATH}:${NACLPORTS_PREFIX}/bin:${PATH}
  export LIBS="-lvorbisfile -lvorbis -logg -lm"
  MakeDir ${BUILD_DIR}
  ChangeDir ${BUILD_DIR}
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
