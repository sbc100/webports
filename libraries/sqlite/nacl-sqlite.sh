#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

MAKE_TARGETS="CCLD=\$(CXX) all"
export LIBS="-lnacl_io"
if [ ${NACL_GLIBC} != "1" ]; then
  LIBS="${LIBS} -lnosys"
  #LDFLAGS="${LDFLAGS} -lncurses -Wl,--whole-archive -lglibc-compat -Wl,--no-whole-archive"
  EXTRA_CONFIGURE_ARGS=--disable-dynamic-extensions
  EXECUTABLE_DIR=.
else
  EXECUTABLE_DIR=.libs
fi

PackageInstall() {
  local SRC_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  if [ -f ${SRC_DIR}/shell.c ]; then
    touch ${SRC_DIR}/shell.c
  fi

  DefaultPackageInstall
  WriteSelLdrScript sqlite3 ${EXECUTABLE_DIR}/sqlite3${NACL_EXEEXT}

  # Build (at least shell.c) again but this time with nacl_io and -DPPAPI
  Banner "Build sqlite3_ppapi"
  touch ${SRC_DIR}/shell.c
  sed -i  "s/sqlite3\$(EXEEXT)/sqlite3_ppapi\$(EXEEXT)/" Makefile
  sed -i  "s/CFLAGS = /CFLAGS = -DPPAPI /" Makefile
  sed -i  "s/-lnacl_io/-lppapi_simple -lnacl_io -lppapi_cpp -lppapi/" Makefile
  BuildStep

  PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/sqlite"
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    PUBLISH_DIR+=/pnacl
  else
    PUBLISH_DIR+=/${NACL_LIBC}
  fi

  MakeDir ${PUBLISH_DIR}

  LogExecute mv ${EXECUTABLE_DIR}/sqlite3_ppapi${NACL_EXEEXT} \
                ${PUBLISH_DIR}/sqlite3_ppapi_${NACL_ARCH}${NACL_EXEEXT}

  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${NACL_CREATE_NMF_FLAGS} \
      ${PUBLISH_DIR}/sqlite3_ppapi*${NACL_EXEEXT} \
      -s ${PUBLISH_DIR} \
      -o sqlite.nmf

  local CHROMEAPPS=${NACL_SRC}/libraries/hterm/src/chromeapps
  local LIB_DOT=${CHROMEAPPS}/libdot
  local NASSH=${CHROMEAPPS}/nassh
  LIBDOT_SEARCH_PATH=${CHROMEAPPS} ${LIB_DOT}/bin/concat.sh \
      -i ${NASSH}/concat/nassh_deps.concat \
      -o ${PUBLISH_DIR}/hterm.concat.js

  LogExecute cp ${START_DIR}/index.html ${PUBLISH_DIR}
  LogExecute cp ${START_DIR}/sqlite.js ${PUBLISH_DIR}
  LogExecute cp sqlite.nmf ${PUBLISH_DIR}
  if [ ${NACL_ARCH} = pnacl ]; then
    sed -i 's/x-nacl/x-pnacl/g' ${PUBLISH_DIR}/sqlite.js
  fi
}

PackageInstall
exit 0
