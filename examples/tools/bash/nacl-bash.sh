#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../../build_tools/common.sh

export EXTRA_CONFIGURE_ARGS="--prefix= --exec-prefix="
export EXTRA_CONFIGURE_ARGS="${EXTRA_CONFIGURE_ARGS} --with-curses"

export EXTRA_LIBS="-ltar -lppapi_simple -lnacl_io -lppapi -lppapi_cpp"
export CONFIG_SUB=support/config.sub

CustomPatchStep() {
  DefaultPatchStep
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  cp ${START_DIR}/bash_pepper.c bash_pepper.c
}

CustomConfigureStep() {
  export CFLAGS="${CFLAGS} -DHAVE_GETHOSTNAME -DNO_MAIN_ENV_ARG"
  DefaultConfigureStep
}

CustomInstallStep() {
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
  cp ${START_DIR}/bash.html ${ASSEMBLY_DIR}
  cd ${ASSEMBLY_DIR}
  python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${NACL_CREATE_NMF_FLAGS} \
      bash_*${NACL_EXEEXT} \
      -s . \
      -o bash.nmf


  local CHROMEAPPS=${NACL_SRC}/libraries/hterm/src/chromeapps
  local LIB_DOT=${CHROMEAPPS}/libdot
  local NASSH=${CHROMEAPPS}/nassh
  LIBDOT_SEARCH_PATH=${CHROMEAPPS} ${LIB_DOT}/bin/concat.sh \
      -i ${NASSH}/concat/nassh_deps.concat \
      -o ${ASSEMBLY_DIR}/hterm.concat.js

  cp ${START_DIR}/bash.js ${ASSEMBLY_DIR}
  cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
  ChangeDir ${PUBLISH_DIR}
  zip -r bash-7.3.zip bash
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  CustomPatchStep
  CustomConfigureStep
  DefaultBuildStep
  DefaultTranslateStep
  DefaultValidateStep
  CustomInstallStep
}

CustomPackageInstall

exit 0
