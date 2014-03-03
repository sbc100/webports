#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export EXTRA_LIBS="-lppapi -lppapi_cpp -lppapi_simple -lcli_main -lnacl_io"
CONFIG_SUB=config/config.sub

BuildStep() {
  # Disable all assembly code by specifying none-none-none.
  DefaultBuildStep --target=none-none-none
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  # -executable is not supported on BSD and -perm +nn is not
  # supported on linux
  if [ ${OS_NAME} != "Darwin" ]; then
    local EXECUTABLES=$(find src -type f -executable)
  else
    local EXECUTABLES=$(find src -type f -perm +u+x)
  fi
  for nexe in ${EXECUTABLES}; do
    local name=$(basename $nexe)
    # This is a shell script.
    if [ "${name}" = "groups" ]; then
      continue
    fi
    cp ${nexe} ${PUBLISH_DIR}/${name}_${NACL_ARCH}${NACL_EXEEXT}

    pushd ${PUBLISH_DIR}
    LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
        ${PUBLISH_DIR}/${name}_*${NACL_EXEEXT} \
        -s . \
        -o ${name}.nmf
    popd
  done
}
