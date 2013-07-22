#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../../build_tools/common.sh

EXECUTABLES=src/nethack

CustomBuildStep() {
  Banner "Building ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  # NOTE: we are using the non-standard vars NACL_CCFLAGS/NACL_LDFLAGS
  # because we are not running ./configure and the Makefile was hacked
  export NACL_CCFLAGS="${NACLPORTS_CFLAGS}"
  export NACL_LDFLAGS="${NACLPORTS_LDFLAGS}"
  if [ ${NACL_ARCH} = "pnacl" ] ; then
    export NACL_CCFLAGS="${NACLPORTS_CFLAGS} -I${NACL_SDK_ROOT}/include -O3 -g"
    export NACL_LDFLAGS="${NACLPORTS_LDFLAGS} -O0 -static"
  fi
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export PATH=${NACL_BIN_PATH}:${PATH};
  export WINTTYLIB="-lncurses -ltar -lppapi_simple -lnacl_io"
  export WINTTYLIB="${WINTTYLIB} -lppapi -lppapi_cpp"
  if [[ "${NACL_ARCH}" = "pnacl" ||
        "${NACL_TOOLCHAIN_ROOT}" == *newlib* ]] ; then
    readonly GLIBC_COMPAT=${NACLPORTS_INCLUDE}/glibc-compat
    export WINTTYLIB="${WINTTYLIB} -lglibc-compat -lnosys"
    export NACL_CCFLAGS="${NACL_CCFLAGS} -I${GLIBC_COMPAT}"
  fi

  export NACLPORTS_INCLUDE
  export STRNCMPI=1
  local PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  ChangeDir ${PACKAGE_DIR}
  cp ${START_DIR}/nethack_pepper.cc ${PACKAGE_DIR}/src
  bash sys/unix/setup.sh
  make
}

CustomInstallStep() {
  Banner "Installing ${PACKAGE_NAME}"

  local PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  ChangeDir ${PACKAGE_DIR}

  make install

  local PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/nethack"
  MakeDir ${ASSEMBLY_DIR}
  cp ${PACKAGE_DIR}/out/games/lib/nethackdir/nethack \
      ${ASSEMBLY_DIR}/nethack_${NACL_ARCH}${NACL_EXEEXT}
  ChangeDir ${PACKAGE_DIR}/out/games
  rm ${PACKAGE_DIR}/out/games/lib/nethackdir/nethack
  tar cf ${ASSEMBLY_DIR}/nethack.tar lib
  cp ${START_DIR}/nethack.html ${ASSEMBLY_DIR}
  pushd ${ASSEMBLY_DIR}
  python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${NACL_CREATE_NMF_FLAGS} \
      nethack_*${NACL_EXEEXT} \
      -s . \
      -o nethack.nmf
  popd
  cp ${NACL_SRC}/libraries/hterm/src/chromeapps/hterm/js/*.js ${ASSEMBLY_DIR}
  cp ${NACL_SRC}/libraries/hterm/src/chromeapps/libdot/js/*.js ${ASSEMBLY_DIR}
  if [ ${NACL_ARCH} = "pnacl" ] ; then
    sed 's/x-nacl/x-pnacl/' \
        ${START_DIR}/nethack.js > ${ASSEMBLY_DIR}/nethack.js
  else
    cp ${START_DIR}/nethack.js ${ASSEMBLY_DIR}
  fi
  cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
  ChangeDir ${PUBLISH_DIR}
  zip -r nethack-3.4.3.zip nethack
  ChangeDir ${PACKAGE_DIR}
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomBuildStep
  DefaultFinalizeStep
  DefaultTranslateStep
  DefaultValidateStep
  CustomInstallStep
}

CustomPackageInstall
exit 0
