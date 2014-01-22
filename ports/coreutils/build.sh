#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export EXTRA_LIBS="-lppapi -lppapi_cpp -lppapi_simple -lcli_main -lnacl_io"
CONFIG_SUB=support/config.sub

BuildStep() {
  # Disable all assembly code by specifying none-none-none.
  DefaultBuildStep --target=none-none-none
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  for nexe in src/*${NACL_EXEEXT}; do
    local name=$(basename $nexe .nexe)
    cp ${nexe} ${PUBLISH_DIR}/${name}_${NACL_ARCH}${NACL_EXEEXT}

    pushd ${PUBLISH_DIR}
    LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
        ${PUBLISH_DIR}/${name}_*${NACL_EXEEXT} \
        -s . \
        -o ${name}.nmf
    popd
  done
}
