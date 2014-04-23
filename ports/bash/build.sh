#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


EXTRA_CONFIGURE_ARGS="--with-curses"
NACLPORTS_CPPFLAGS+=" -DHAVE_GETHOSTNAME -DNO_MAIN_ENV_ARG"
export EXTRA_LIBS="${NACL_CLI_MAIN_LIB} -ltar \
-lppapi_simple -lnacl_spawn -lnacl_io -lppapi -lppapi_cpp"
CONFIG_SUB=support/config.sub

PatchStep() {
  DefaultPatchStep
  ChangeDir ${SRC_DIR}
  cp ${START_DIR}/bash_pepper.c bash_pepper.c
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/bash"

  DESTDIR=${ASSEMBLY_DIR}/bashtar
  MAKEFLAGS="prefix="
  DefaultInstallStep

  ChangeDir ${ASSEMBLY_DIR}/bashtar
  cp bin/bash${NACL_EXEEXT} ../bash_${NACL_ARCH}${NACL_EXEEXT}
  rm -rf bin
  rm -rf share/man
  tar cf ${ASSEMBLY_DIR}/bash.tar .
  rm -rf ${ASSEMBLY_DIR}/bashtar
  cd ${ASSEMBLY_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      bash_*${NACL_EXEEXT} \
      -s . \
      -o bash.nmf
  LogExecute python ${TOOLS_DIR}/create_term.py bash.nmf

  InstallNaClTerm ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/background.js ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
  ChangeDir ${PUBLISH_DIR}
  LogExecute zip -r bash-7.3.zip bash
}
