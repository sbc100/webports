#!/bin/bash
# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

NACL_CONFIGURE_PATH=${BUILD_DIR}/configure

EXTRA_CONFIGURE_ARGS="--prefix=${DESTDIR}/payload"
EXTRA_CONFIGURE_ARGS+=" --with-components=core-and-image"
EXTRA_CONFIGURE_ARGS+=" --disable-gssapi --disable-threads"

ConfigureStep() {
  if [ "${NACL_LIBC}" = "newlib" ]; then
    NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
    EXTRA_CONFIGURE_ARGS+=" --disable-shared --enable-static"
    export LIBS+=" -lglibc-compat"
    export LSB_BUILD="y"
  fi

  # Copy all sources to the build directory because cups does not support
  # out-of-tree builds.
  LogExecute cp -R ${SRC_DIR}/* .

  # Add a file that provides a dummy implementation of uname().
  cp ${START_DIR}/uname.c cups

  DefaultConfigureStep
}
