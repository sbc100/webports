#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

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
    export WINTTYLIB="${WINTTYLIB} -lglibc-compat"
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

  pushd ${ASSEMBLY_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      nethack_*${NACL_EXEEXT} \
      -s . \
      -o nethack.nmf
  LogExecute python ${TOOLS_DIR}/create_term.py nethack.nmf
  popd
  # Create a copy of nethack for debugging.
  LogExecute cp ${ASSEMBLY_DIR}/nethack.nmf ${ASSEMBLY_DIR}/nethack_debug.nmf
  sed 's/nethack\.js/nethack_debug.js/' \
      ${ASSEMBLY_DIR}/nethack.html > ${ASSEMBLY_DIR}/nethack_debug.html
  sed 's/nethack\.nmf/nethack_debug.nmf/' \
      ${ASSEMBLY_DIR}/nethack.js > ${ASSEMBLY_DIR}/nethack_debug.js

  local PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"

  # Uncomment these lines to copy over source tree as a gdb sample.
  # Do not submit otherwise nethack source tree will be uploaded to
  # along with the rest of the 'out/publish' tree.
  #local ASSEMBLY_SRC_DIR="${PUBLISH_DIR}/nethack_src"
  #LogExecute rm -rf ${ASSEMBLY_SRC_DIR}
  #LogExecute cp -r ${PACKAGE_DIR} ${ASSEMBLY_SRC_DIR}

  local MANIFEST_PATH="${PUBLISH_DIR}/nethack.manifest"
  LogExecute rm -f ${MANIFEST_PATH}
  pushd ${PUBLISH_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/genhttpfs.py \
      -r -o /tmp/nethack_manifest.tmp .
  LogExecute cp /tmp/nethack_manifest.tmp ${MANIFEST_PATH}
  popd

  InstallNaClTerm ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
  ChangeDir ${PUBLISH_DIR}
  LogExecute zip -r nethack-3.4.3.zip nethack
  ChangeDir ${PACKAGE_DIR}
}

PackageInstall
exit 0
