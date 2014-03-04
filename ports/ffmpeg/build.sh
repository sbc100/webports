#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="ffmpeg ffmpeg_g ffprobe ffprobe_g"

ConfigureStep() {
  SetupCrossEnvironment

  local extra_args=""
  if [ "${NACL_ARCH}" = pnacl ]; then
    extra_args="--cc=pnacl-clang --arch=pnacl"
  elif [ "${NACL_ARCH}" = arm ]; then
    extra_args="--arch=arm"
  else
    extra_args="--arch=x86"
  fi

  if [[ "${NACL_GLIBC}" != "1" ]]; then
    # This is needed for sys/ioctl.h.
    # TODO(sbc): Remove once sys/ioctl.h is added to newlib SDK
    CFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
    export CFLAGS
    extra_args+=" --extra-libs=-lglibc-compat"
  fi

  LogExecute ../configure \
    --cross-prefix=${NACL_CROSS_PREFIX}- \
    --target-os=linux \
    --enable-gpl \
    --enable-static \
    --enable-cross-compile \
    --disable-inline-asm \
    --disable-ssse3 \
    --disable-mmx \
    --disable-amd3dnow \
    --disable-amd3dnowext \
    --disable-indevs \
    --disable-protocols \
    --disable-network \
    --enable-protocol=file \
    --enable-libmp3lame \
    --enable-libvorbis \
    --enable-libtheora \
    --disable-ffplay \
    --disable-ffserver \
    --disable-demuxer=rtsp \
    --disable-demuxer=image2 \
    --prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    ${extra_args}
}
