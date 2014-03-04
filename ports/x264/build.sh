#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}

ConfigureStep() {
  SetupCrossEnvironment

  local conf_host
  if [ "${NACL_ARCH}" = pnacl ]; then
    conf_host=pnacl
  else
    conf_host=${NACL_CROSS_PREFIX}
  fi

  LogExecute ./configure \
    --cross-prefix=${NACL_CROSS_PREFIX} \
    --disable-asm \
    --disable-pthread \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    --extra-ldflags="-lm" \
    --host=${conf_host}

  make clean
}
