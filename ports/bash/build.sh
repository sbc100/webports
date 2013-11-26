#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

export EXTRA_CONFIGURE_ARGS="--prefix= --exec-prefix="
export EXTRA_CONFIGURE_ARGS="${EXTRA_CONFIGURE_ARGS} --with-curses"

export EXTRA_LIBS="-ltar -lppapi_simple -lnacl_io -lppapi -lppapi_cpp"
export CONFIG_SUB=support/config.sub

PatchStep() {
  DefaultPatchStep
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  cp ${START_DIR}/bash_pepper.c bash_pepper.c
}

ConfigureStep() {
  export NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS} -DHAVE_GETHOSTNAME -DNO_MAIN_ENV_ARG"
  DefaultConfigureStep
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/bash"

  export INSTALL_TARGETS="DESTDIR=${ASSEMBLY_DIR}/bashtar install"
  DefaultInstallStep

  ChangeDir ${ASSEMBLY_DIR}/bashtar
  cp bin/bash ../bash_${NACL_ARCH}${NACL_EXEEXT}
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
  LogExecute cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
  ChangeDir ${PUBLISH_DIR}
  LogExecute zip -r bash-7.3.zip bash
}

PackageInstall
exit 0
