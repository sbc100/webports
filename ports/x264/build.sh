# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}
EXECUTABLES=x264${NACL_EXEEXT}

ConfigureStep() {
  SetupCrossEnvironment

  local conf_host
  if [ "${NACL_ARCH}" = pnacl ]; then
    conf_host=nacl-pnacl
  else
    conf_host=${NACL_CROSS_PREFIX}
  fi

  LogExecute ./configure \
    --host=${conf_host} \
    --prefix=${PREFIX} \
    --cross-prefix=${NACL_CROSS_PREFIX}- \
    --disable-asm \
    --disable-thread

  LogExecute make clean
}
