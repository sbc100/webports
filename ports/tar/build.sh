#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export EXTRA_LIBS="-lppapi -lppapi_cpp -lppapi_simple -lcli_main -lnacl_io"
CONFIG_SUB=config/config.sub

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  cp src/tar ${PUBLISH_DIR}/tar_${NACL_ARCH}${NACL_EXEEXT}
  pushd ${PUBLISH_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${PUBLISH_DIR}/tar_*${NACL_EXEEXT} \
      -s . \
      -o tar.nmf
  popd
}
