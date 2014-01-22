#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export EXTRA_LIBS="-lppapi -lppapi_cpp -lppapi_simple -lcli_main -lnacl_io"
CONFIG_SUB=support/config.sub

ConfigureStep() {
  # TODO(hamaji): GCC cannot find its own path so that it cannot
  # specify correct path info using a relative path from the gcc
  # binary. For now, we specify sysroot at compile time, but we would
  # want to remove the --with-sysroot flag.
  DefaultConfigureStep \
    --target=x86_64-nacl \
    --with-sysroot=/mnt/html5/mingn \
    --disable-werror --enable-deterministic-archives --without-zlib
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  for nexe in binutils/*.nexe gas/*.nexe ld/*.nexe; do
    local name=$(basename $nexe .nexe | sed 's/-new//')
    cp ${nexe} ${PUBLISH_DIR}/${name}_${NACL_ARCH}${NACL_EXEEXT}

    pushd ${PUBLISH_DIR}
    LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
        ${PUBLISH_DIR}/${name}_*${NACL_EXEEXT} \
        -s . \
        -o ${name}.nmf
    popd
  done
}
