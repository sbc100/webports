#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


EXTRA_CONFIGURE_ARGS="--with-curses"
EXTRA_CONFIGURE_ARGS+=" --with-installed-readline --enable-readline"
NACLPORTS_CPPFLAGS+=" -DHAVE_GETHOSTNAME -DNO_MAIN_ENV_ARG"
export EXTRA_LIBS="${NACL_CLI_MAIN_LIB} \
-lppapi_simple -lnacl_spawn -lnacl_io -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"
CONFIG_SUB=support/config.sub

export bash_cv_getcwd_malloc=yes

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
fi

PatchStep() {
  DefaultPatchStep
  ChangeDir ${SRC_DIR}
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/bash"

  MakeDir ${ASSEMBLY_DIR}/_platform_specific/${NACL_ARCH}
  LogExecute cp ${BUILD_DIR}/bash${NACL_EXEEXT} \
      ${ASSEMBLY_DIR}/_platform_specific/${NACL_ARCH}/bash${NACL_EXEEXT}
  ChangeDir ${ASSEMBLY_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      _platform_specific/*/bash*${NACL_EXEEXT} \
      -s . \
      -o bash.nmf
  LogExecute python ${TOOLS_DIR}/create_term.py bash.nmf

  InstallNaClTerm ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/background.js ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/devenv_16.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/devenv_48.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/devenv_128.png ${ASSEMBLY_DIR}
}
