#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

NACL_CONFIGURE_PATH=${SRC_DIR}/unix/configure

if [ "${NACL_SHARED}" = "0" ]; then
  EXTRA_CONFIGURE_ARGS="--disable-shared"
  MAKE_TARGETS="libmk4.a"
else
  MAKE_TARGETS="libmk4.so libmk4.a"
fi

AutoconfStep() {
  pushd ${SRC_DIR}/unix
  autoconf
  popd
}

ConfigureStep() {
  AutoconfStep
  DefaultConfigureStep
}
