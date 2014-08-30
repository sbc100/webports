#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -D_POSIX_VERSION"
fi

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  cp make${NACL_EXEEXT} ${PUBLISH_DIR}/make_${NACL_ARCH}${NACL_EXEEXT}

  pushd ${PUBLISH_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${PUBLISH_DIR}/make_*${NACL_EXEEXT} \
      -s . \
      -o make.nmf
  popd
}
