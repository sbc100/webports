#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

ConfigureStep() {
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export PATH=${NACL_BIN_PATH}:${PATH};
  MakeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}/${NACL_BUILD_SUBDIR}
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}/${NACL_BUILD_SUBDIR}
  local extra_args=""
  if [ "${NACL_ARCH}" = pnacl ]; then
    extra_args="--cc=pnacl-clang --arch=pnacl"
  fi

  if [[ "${NACL_GLIBC}" != "1" ]]; then
    # This is needed for sys/ioctl.h.
    # TODO(sbc): Remove once sys/ioctl.h is added to newlib SDK
    CFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
    export CFLAGS
    extra_args+=" --extra-libs=-lglibc-compat"
  fi

  ../configure \
    --cross-prefix=${NACL_CROSS_PREFIX}- \
    ${extra_args} \
    --target-os=linux \
    --enable-gpl \
    --enable-static \
    --enable-cross-compile \
    --disable-ssse3 \
    --disable-mmx \
    --disable-mmx2 \
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
    --libdir=${NACLPORTS_LIBDIR}

  touch strings.h
}
