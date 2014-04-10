#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

CONFIG_SUB=build-scripts/config.sub

# TODO: Remove when this is fixed.
# https://code.google.com/p/nativeclient/issues/detail?id=3598
if [ "$NACL_LIBC" = "glibc" ]; then
  export NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS//-O2/}"
fi

ConfigureStep() {
  SetupCrossEnvironment
  export LIBS="-lvorbisfile -lvorbis -logg -lm"
  ${SRC_DIR}/configure \
    --host=nacl \
    --prefix=${PREFIX} \
    --${NACL_OPTION}-mmx \
    --${NACL_OPTION}-sse \
    --${NACL_OPTION}-sse2 \
    --${NACL_OPTION}-asm \
    --with-x=no \
    --disable-music-flac \
    --disable-music-mp3
}
