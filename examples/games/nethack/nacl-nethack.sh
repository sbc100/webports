#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../../build_tools/common.sh

set -x

EXECUTABLES=src/nethack

CustomBuildStep() {
  Banner "Building ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  # NOTE: we are using the non-standard vars NACL_CCFLAGS/NACL_LDFLAGS
  # because we are not running ./configure and the Makefile was hacked
  export NACL_CCFLAGS="${NACLPORTS_CFLAGS} -I${NACL_SDK_ROOT}/include -O"
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
  export WINTTYLIB="-Wl,--whole-archive"
  export WINTTYLIB="$WINTTYLIB -lnacl-mounts -lncurses -lppapi -lppapi_cpp -lppapi_cpp_private"
  export WINTTYLIB="$WINTTYLIB -Wl,--no-whole-archive"
  export NACLPORTS_INCLUDE
  export STRNCMPI=1
  local PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  ChangeDir ${PACKAGE_DIR}
  cp ${START_DIR}/nethack_pepper.cc ${PACKAGE_DIR}/src
  bash sys/unix/setup.sh
  make
  make install
  Banner "Installing ${PACKAGE_NAME}"
  local PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/nethack"
  MakeDir ${ASSEMBLY_DIR}
  cp ${PACKAGE_DIR}/out/games/lib/nethackdir/nethack \
      ${ASSEMBLY_DIR}/nethack_${NACL_ARCH}.nexe
  ChangeDir ${PACKAGE_DIR}/out/games
  rm ${PACKAGE_DIR}/out/games/lib/nethackdir/nethack
  tar cf ${ASSEMBLY_DIR}/nethack.tar lib
  cp ${START_DIR}/nethack.html ${ASSEMBLY_DIR}
  if [ "${NACL_GLIBC}" = "1" ]; then
    pushd ${ASSEMBLY_DIR}
    TRUE_TOOLCHAIN_DIR=$(cd ${NACL_SDK_ROOT}/toolchain && pwd -P)
    python ${TRUE_TOOLCHAIN_DIR}/../tools/create_nmf.py \
        *.nexe \
        -L ${NACL_TOOLCHAIN_ROOT}/x86_64-nacl/lib32 \
        -L ${NACL_SDK_LIBDIR} \
        -L ${NACL_TOOLCHAIN_ROOT}/x86_64-nacl/lib64 \
        -D ${NACL_TOOLCHAIN_ROOT}/bin/x86_64-nacl-objdump \
        -s . \
        -o nethack.nmf
    popd
  else
    cp ${START_DIR}/nethack.nmf ${ASSEMBLY_DIR}
  fi
  cp ${NACLPORTS_LIBDIR}/nacl-mounts/*.js ${ASSEMBLY_DIR}
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
  DefaultTranslateStep
  DefaultValidateStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
