#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-thttpd-2.25.sh
#
# Usage:  nacl-thttpd-2.25.sh
#
# This script downloads, patches, and builds thttpd server for Native Client.

readonly URL='http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/thttpd-2.25b.tgz'
readonly PATCH_FILE=nacl-thttpd-2.25b.patch
PACKAGE_NAME=thttpd-2.25b

source ../../../build_tools/common.sh

PreConfigureStep() {
  Banner "Pre-configuring ${PACKAGE_NAME}"

  local PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  ChangeDir ${PACKAGE_DIR}
  FILES="jsdirectoryreader.cpp
jsdirectoryreader.h
my_syslog.h
mythread.cpp
mythread.h
nacl_module.cpp
nacl_module.h
shelljob.h
syslog.cpp
Makefile"
  for FILE in $FILES
  do
    cp -f ${START_DIR}/${FILE} .
  done
}

CustomBuildStep() {
  Banner "Building ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export NACLXX=${NACLCXX}
  export CXX=${NACLCXX}
  if [ ${NACL_PACKAGES_BITSIZE} == "pnacl" ] ; then
    export NACL_CCFLAGS="-O3 -g"
    export NACL_LDFLAGS="-O0 -static"
  fi
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACL_SDK_USR_LIB}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACL_SDK_USR_LIB}
  export PATH=${NACL_BIN_PATH}:${PATH};
  local PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  ChangeDir ${PACKAGE_DIR}
  make thttpd
}

CustomInstallStep() {
  PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
  local PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}
  install ${START_DIR}/thttpd.html ${PUBLISH_DIR}
  install ${START_DIR}/nacl.js ${PUBLISH_DIR}
  install ${START_DIR}/peppermount_helper.js ${PUBLISH_DIR}
  install ${START_DIR}/json2min.js ${PUBLISH_DIR}
  BUILD_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  cp ${BUILD_DIR}/thttpd ${BUILD_DIR}/thttpd_x86-${NACL_PACKAGES_BITSIZE}.nexe
  install ${BUILD_DIR}/thttpd_x86-${NACL_PACKAGES_BITSIZE}.nexe \
      ${PUBLISH_DIR}/thttpd_x86-${NACL_PACKAGES_BITSIZE}.nexe
  ChangeDir ${PUBLISH_DIR}
  local NACL_LIB_PATH=$NACL_TOOLCHAIN_ROOT/x86_64-nacl
  local NACL_COMPLEMENT_BITSIZE=64
  if [ ${NACL_PACKAGES_BITSIZE} == "64" ]; then
    NACL_COMPLEMENT_BITSIZE=32
  fi
  if [ -f thttpd_x86-${NACL_COMPLEMENT_BITSIZE}.nexe ]; then
    $NACL_SDK_ROOT/tools/create_nmf.py \
      -L$NACL_LIB_PATH/usr/lib$NACL_COMPLEMENT_BITSIZE \
      -L$NACL_LIB_PATH/lib$NACL_COMPLEMENT_BITSIZE \
      -L$NACL_LIB_PATH/usr/lib$NACL_PACKAGES_BITSIZE \
      -L$NACL_LIB_PATH/lib$NACL_PACKAGES_BITSIZE \
      -o thttpd.nmf -s . \
      thttpd_x86-${NACL_COMPLEMENT_BITSIZE}.nexe \
      thttpd_x86-${NACL_PACKAGES_BITSIZE}.nexe
  else
    $NACL_SDK_ROOT/tools/create_nmf.py \
      -L$NACL_LIB_PATH/usr/lib$NACL_PACKAGES_BITSIZE \
      -L$NACL_LIB_PATH/lib$NACL_PACKAGES_BITSIZE -o thttpd.nmf -s . \
      thttpd_x86-${NACL_PACKAGES_BITSIZE}.nexe
  fi
  DefaultTouchStep
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  PreConfigureStep
  CustomBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
