#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-nethack-343.sh
#
# usage:  nacl-nethack-343.sh
#
# this script downloads, patches, and builds nethack for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/nethack-343-src.tgz
readonly PATCH_FILE=nacl-nethack-3.4.3.patch
readonly PACKAGE_NAME=nethack-3.4.3

source ../../../build_tools/common.sh


set -x


CustomBuildStep() {
  Banner "Building ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  # NOTE: we are using the non-standard vars NACL_CCFLAGS/NACL_LDFLAGS
  # because we are not running ./configure and the Makefile was hacked
  export NACL_CCFLAGS="-O"
  export NACL_LDFLAGS=""
  if [ ${NACL_PACKAGES_BITSIZE} == "pnacl" ] ; then
    export NACL_CCFLAGS="-O3 -g"
    export NACL_LDFLAGS="-O0 -static"
  fi
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACL_SDK_USR_LIB}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACL_SDK_USR_LIB}
  export PATH=${NACL_BIN_PATH}:${PATH};
  export WINTTYLIB="-Wl,--whole-archive"
  export WINTTYLIB="$WINTTYLIB -lnacl-mounts -lncurses -lppapi -lppapi_cpp"
  export WINTTYLIB="$WINTTYLIB -Wl,--no-whole-archive"
  export NACL_SDK_USR_INCLUDE
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
      ${ASSEMBLY_DIR}/nethack_x86-${NACL_PACKAGES_BITSIZE:-"32"}.nexe
  ChangeDir ${PACKAGE_DIR}/out/games
  rm ${PACKAGE_DIR}/out/games/lib/nethackdir/nethack
  tar cf ${ASSEMBLY_DIR}/nethack.tar lib
  cp ${START_DIR}/nethack.html ${ASSEMBLY_DIR}
  if [ "${NACL_GLIBC}" = "1" ]; then
    pushd ${NACL_SDK_USR}
    tar cf ${ASSEMBLY_DIR}/terminfo.tar share
    popd

    pushd ${ASSEMBLY_DIR}
    TRUE_TOOLCHAIN_DIR=$(cd ${NACL_SDK_ROOT}/toolchain && pwd -P)
    python ${TRUE_TOOLCHAIN_DIR}/../tools/create_nmf.py \
        *.nexe \
        -L ${NACL_TOOLCHAIN_ROOT}/x86_64-nacl/lib32 \
        -L ${NACL_TOOLCHAIN_ROOT}/x86_64-nacl/lib64 \
        -D ${NACL_TOOLCHAIN_ROOT}/bin/x86_64-nacl-objdump \
        -s . \
        -o nethack.nmf
    popd
  else
    cp ${START_DIR}/nethack.nmf ${ASSEMBLY_DIR}
  fi
  cp ${NACL_SDK_USR_LIB}/nacl-mounts/*.js ${ASSEMBLY_DIR}
  cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
  ChangeDir ${PUBLISH_DIR}
  zip -r nethack-3.4.3.zip nethack
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomBuildStep
  if [ ${NACL_PACKAGES_BITSIZE} == "pnacl" ] ; then
    # NOTE: nethack does not use a build subdir
    DefaultTranslateStep ${PACKAGE_NAME} src/nethack
  fi
  DefaultTouchStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
