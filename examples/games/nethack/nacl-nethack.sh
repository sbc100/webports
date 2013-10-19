#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../../build_tools/common.sh

EXECUTABLES=src/nethack

BuildStep() {
  Banner "Building ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  # NOTE: we are using the non-standard vars NACL_CCFLAGS/NACL_LDFLAGS
  # because we are not running ./configure and the Makefile was hacked
  export NACL_CCFLAGS="${NACLPORTS_CFLAGS}"
  export NACL_LDFLAGS="${NACLPORTS_LDFLAGS}"
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

InstallStep() {
  Banner "Installing ${PACKAGE_NAME}"
  local PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  ChangeDir ${PACKAGE_DIR}

  make install

  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/nethack"
  MakeDir ${ASSEMBLY_DIR}
  cp ${PACKAGE_DIR}/out/games/lib/nethackdir/nethack \
      ${ASSEMBLY_DIR}/nethack_${NACL_ARCH}${NACL_EXEEXT}
  ChangeDir ${PACKAGE_DIR}/out/games
  LogExecute rm ${PACKAGE_DIR}/out/games/lib/nethackdir/nethack
  LogExecute tar cf ${ASSEMBLY_DIR}/nethack.tar lib
  LogExecute cp ${START_DIR}/nethack.html ${ASSEMBLY_DIR}
  pushd ${ASSEMBLY_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${NACL_CREATE_NMF_FLAGS} \
      nethack_*${NACL_EXEEXT} \
      -s . \
      -o nethack.nmf
  popd
  # Create a copy of nethack for debugging.
  LogExecute cp ${ASSEMBLY_DIR}/nethack.nmf ${ASSEMBLY_DIR}/nethack_debug.nmf
  sed 's/nethack\.js/nethack_debug.js/' \
      ${START_DIR}/nethack.html > ${ASSEMBLY_DIR}/nethack_debug.html
  sed 's/nethack\.nmf/nethack_debug.nmf/' \
      ${START_DIR}/nethack.js > ${ASSEMBLY_DIR}/nethack_debug.js

  # Copy over source tree as a gdb sample.
  local PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  local ASSEMBLY_SRC_DIR="${PUBLISH_DIR}/nethack_src"
  local MANIFEST_PATH="${PUBLISH_DIR}/nethack.manifest"
  LogExecute rm -f ${MANIFEST_PATH}
  LogExecute rm -rf ${ASSEMBLY_SRC_DIR}
  LogExecute cp -r ${PACKAGE_DIR} ${ASSEMBLY_SRC_DIR}
  pushd ${PUBLISH_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/genhttpfs.py \
      -r -o /tmp/nethack_manifest.tmp .
  LogExecute cp /tmp/nethack_manifest.tmp ${MANIFEST_PATH}
  popd

  local CHROMEAPPS=${NACL_SRC}/libraries/hterm/src/chromeapps
  local LIB_DOT=${CHROMEAPPS}/libdot
  local NASSH=${CHROMEAPPS}/nassh
  LIBDOT_SEARCH_PATH=${CHROMEAPPS} ${LIB_DOT}/bin/concat.sh \
      -i ${NASSH}/concat/nassh_deps.concat \
      -o ${ASSEMBLY_DIR}/hterm.concat.js

  LogExecute cp ${START_DIR}/nethack.js ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
  LogExecute cp ${NACL_SRC}/build_tools/naclterm.js ${ASSEMBLY_DIR}
  if [ ${NACL_ARCH} = "pnacl" ] ; then
    sed -i.bak 's/x-nacl/x-pnacl/g' ${ASSEMBLY_DIR}/naclterm.js
  fi
  ChangeDir ${PUBLISH_DIR}
  LogExecute zip -r nethack-3.4.3.zip nethack
  ChangeDir ${PACKAGE_DIR}
}

PackageInstall
exit 0
