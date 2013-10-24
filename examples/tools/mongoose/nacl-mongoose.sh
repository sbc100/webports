#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../../build_tools/common.sh

BuildStep() {
  export EXTRA_CFLAGS="${NACL_CFLAGS}"
  export LDFLAGS="${NACL_LDFLAGS} -lppapi_simple -lnacl_io -lppapi_cpp -lppapi"
  if [ "$NACL_GLIBC" = "1" ]; then
    LDFLAGS+=" -ldl"
  fi
  CC=${NACLCC} LogExecute make clean
  CC=${NACLCC} LogExecute make nacl
}

InstallStep() {
  Banner "Installing ${PACKAGE_NAME}"
  local PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"

  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/mongoose"
  MakeDir ${ASSEMBLY_DIR}
  LogExecute cp mongoose \
      ${ASSEMBLY_DIR}/mongoose_${NACL_ARCH}${NACL_EXEEXT}
  LogExecute cp ${START_DIR}/index.html ${ASSEMBLY_DIR}
  pushd ${ASSEMBLY_DIR}
  python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${NACL_CREATE_NMF_FLAGS} \
      mongoose_*${NACL_EXEEXT} \
      -s . \
      -o mongoose.nmf
  popd

  local CHROMEAPPS=${NACL_SRC}/libraries/hterm/src/chromeapps
  local LIB_DOT=${CHROMEAPPS}/libdot
  local NASSH=${CHROMEAPPS}/nassh
  LIBDOT_SEARCH_PATH=${CHROMEAPPS} ${LIB_DOT}/bin/concat.sh \
      -i ${NASSH}/concat/nassh_deps.concat \
      -o ${ASSEMBLY_DIR}/hterm.concat.js

  if [ ${NACL_ARCH} = "pnacl" ] ; then
    sed 's/x-nacl/x-pnacl/' \
        ${TOOLS_DIR}/naclterm.js > ${ASSEMBLY_DIR}/naclterm.js
  else
    LogExecute cp ${TOOLS_DIR}/naclterm.js ${ASSEMBLY_DIR}
  fi
  LogExecute cp ${START_DIR}/background.js ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/mongoose.js ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  LogExecute cp ${NACL_SRC}/build_tools/naclterm.js ${ASSEMBLY_DIR}
}

PackageInstall
exit 0
