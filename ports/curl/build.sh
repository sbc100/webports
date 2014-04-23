#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export ac_cv_func_gethostbyname=yes
export ac_cv_func_getaddrinfo=no
export ac_cv_func_connect=yes
export LIBS="-lnacl_io -lpthread -l${NACL_CPP_LIB}"

if [ "${NACL_SHARED}" = "1" ]; then
  EXECUTABLE_DIR=.libs
else
  EXECUTABLE_DIR=.
fi

EXECUTABLES=src/${EXECUTABLE_DIR}/curl${NACL_EXEEXT}
CFLAGS+=" -DDEBUGBUILD"
#EXTRA_CONFIGURE_ARGS="--enable-debug --disable-curldebug"

BuildStep() {
  # Run the build twice, initially to build the sel_ldr version
  # and secondly to build the PPAPI version based on nacl_io.
  # Touch tool_main.c to ensure that it gets rebuilt each time.
  # This is the only file that depends on the PPAPI define and
  # therefore will differ between PPAPI and sel_ldr versions.
  if [ -f ${SRC_DIR}/src/tool_main.c ]; then
    touch ${SRC_DIR}/src/tool_main.c
  fi
  DefaultBuildStep

  Banner "Build curl_ppapi"
  touch ${SRC_DIR}/src/tool_main.c
  sed -i.bak "s/CFLAGS = /CFLAGS = -DPPAPI /" src/Makefile
  sed -i.bak "s/curl\$(EXEEXT)/curl_ppapi\$(EXEEXT)/" src/Makefile
  local sedlibs="-lppapi_simple -lnacl_io -lppapi_cpp -lppapi -l${NACL_CPP_LIB}"
  sed -i.bak "s/LIBS = \$(BLANK_AT_MAKETIME)/LIBS = ${sedlibs}/" src/Makefile
  DefaultBuildStep
}

InstallStep() {
  DefaultInstallStep
  PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/curl"
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    # Just set up the x86-64 version for now.
    local pexe="${EXECUTABLE_DIR}/curl${NACL_EXEEXT}"
    (cd src;
     TranslateAndWriteSelLdrScript ${pexe} x86-64 curl.x86-64.nexe curl
    )
    PUBLISH_DIR+="/pnacl"
  else
    PUBLISH_DIR+="/${NACL_LIBC}"
  fi

  MakeDir ${PUBLISH_DIR}

  local exe=${PUBLISH_DIR}/curl_ppapi_${NACL_ARCH}${NACL_EXEEXT}

  LogExecute mv src/${EXECUTABLE_DIR}/curl_ppapi${NACL_EXEEXT} ${exe}
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    LogExecute ${PNACLFINALIZE} ${exe}
  fi

  pushd ${PUBLISH_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${PUBLISH_DIR}/curl_ppapi*${NACL_EXEEXT} \
      -L${DESTDIR_LIB} \
      -s . \
      -o curl.nmf
  popd

  InstallNaClTerm ${PUBLISH_DIR}
  LogExecute cp ${START_DIR}/index.html ${PUBLISH_DIR}
  LogExecute cp ${START_DIR}/curl.js ${PUBLISH_DIR}
}
