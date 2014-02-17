#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export EXTRA_LIBS=\
"-lppapi -lppapi_cpp -lppapi_simple -lcli_main -lnacl_io -lnacl_spawn"
CONFIG_SUB=support/config.sub
# --with-build-sysroot is necessary to run "fixincl"
# properly. Without this option, GCC's build system tries to create
# "include-fixed" based on the host's include directory, which is
# not compatible with nacl-gcc.
EXTRA_CONFIGURE_ARGS="\
    --enable-languages=c,c++ --disable-nls \
    --target=x86_64-nacl \
    --disable-libstdcxx-pch --enable-threads=nacl"

ConfigureStep() {
  DefaultConfigureStep
  LogExecute rm -f `find -name config.cache`
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  for nexe in gcc/xgcc gcc/g++ gcc/cpp gcc/cc1 gcc/cc1plus gcc/collect2; do
    local name=$(basename $nexe | sed 's/xgcc/gcc/')
    cp ${nexe} ${PUBLISH_DIR}/${name}_${NACL_ARCH}${NACL_EXEEXT}

    pushd ${PUBLISH_DIR}
    LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
        ${PUBLISH_DIR}/${name}_*${NACL_EXEEXT} \
        -s . \
        -o ${name}.nmf
    popd
  done
}
