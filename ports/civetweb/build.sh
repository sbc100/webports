#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

EXECUTABLES=civetweb

BuildStep() {
  Banner "Building ${PACKAGE_NAME}"

  export CFLAGS="${NACL_CFLAGS}"
  export LDFLAGS="${NACL_LDFLAGS}"

  CFLAGS+=" -DNO_SSL -DNO_CGI"
  if [ "${NACL_GLIBC}" = "1" ]; then
    LDFLAGS+=" -ldl"
  fi

  CC=${NACLCC} LogExecute make clean
  CC=${NACLCC} LogExecute make WITH_DEBUG=${NACL_DEBUG} \
                               TARGET_OS=NACL WITH_CPP=1 all lib
}

PublishStep() {
  Banner "Publishing ${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/civetweb"
  MakeDir ${ASSEMBLY_DIR}
  LogExecute cp civetweb \
      ${ASSEMBLY_DIR}/civetweb_${NACL_ARCH}${NACL_EXEEXT}
  LogExecute cp ${START_DIR}/index.html ${ASSEMBLY_DIR}

  pushd ${ASSEMBLY_DIR}
  python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      civetweb_*${NACL_EXEEXT} \
      -s . \
      -o civetweb.nmf
  popd

  InstallNaClTerm ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/background.js ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/civetweb.js ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
}

InstallStep() {
  Banner "Installing ${PACKAGE_NAME}"

  LogExecute cp libcivetweb.a $NACL_TOOLCHAIN_PREFIX/lib
  MakeDir $NACL_TOOLCHAIN_PREFIX/include/civetweb
  LogExecute cp include/civetweb.h $NACL_TOOLCHAIN_PREFIX/include/civetweb
  LogExecute cp include/CivetServer.h $NACL_TOOLCHAIN_PREFIX/include/civetweb
  PublishStep
}

PackageInstall
exit 0
