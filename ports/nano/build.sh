#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export EXTRA_LIBS="${NACL_CLI_MAIN_LIB} -lncurses -ltar -lppapi_simple \
  -lnacl_io -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"
export EXTRA_CONFIGURE_ARGS="--prefix= --exec-prefix="
if [ "${NACL_GLIBC}" != "1" ]; then
  export EXTRA_LIBS="${EXTRA_LIBS} -lglibc-compat"
  export EXTRA_CONFIGURE_ARGS="${EXTRA_CONFIGURE_ARGS} --enable-tiny"
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
fi

PatchStep() {
  DefaultPatchStep
  cp ${START_DIR}/nano_pepper.c ${SRC_DIR}/src/
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/nano"

  export INSTALL_TARGETS="install DESTDIR=${ASSEMBLY_DIR}/nanotar"
  DefaultInstallStep

  ChangeDir ${ASSEMBLY_DIR}/nanotar
  local exe="../nano_${NACL_ARCH}${NACL_EXEEXT}"
  cp bin/nano${NACL_EXEEXT} ${exe}
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    LogExecute ${PNACLFINALIZE} ${exe}
  fi
  rm -rf bin
  rm -rf share/man
  tar cf ${ASSEMBLY_DIR}/nano.tar .
  rm -rf ${ASSEMBLY_DIR}/nanotar
  cd ${ASSEMBLY_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      nano_*${NACL_EXEEXT} \
      -s . \
      -o nano.nmf
  LogExecute python ${TOOLS_DIR}/create_term.py nano.nmf

  InstallNaClTerm ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
  ChangeDir ${PUBLISH_DIR}
  LogExecute zip -r nano-7.3.zip nano
}
