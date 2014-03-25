#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

ConfigureStep() {
  SetupCrossEnvironment
  ${SRC_DIR}/configure \
    --host=nacl \
    --prefix=${PREFIX} \
    --${NACL_OPTION}-mmx \
    --${NACL_OPTION}-sse \
    --${NACL_OPTION}-sse2 \
    --${NACL_OPTION}-asm \
    --with-x=no \
    --with-included-modules \
    --without-dynamic-modules
}
