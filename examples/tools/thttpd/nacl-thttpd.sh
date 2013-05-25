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

source pkg_info
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
  # The checked-in Makefile has more configuration for this example.
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export PATH=${NACL_BIN_PATH}:${PATH};
  export NACLPORTS_CFLAGS
  export NACLPORTS_LDFLAGS
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
  cp ${BUILD_DIR}/thttpd ${BUILD_DIR}/thttpd_${NACL_ARCH}.nexe
  install ${BUILD_DIR}/thttpd_${NACL_ARCH}.nexe \
      ${PUBLISH_DIR}/thttpd_${NACL_ARCH}.nexe
  ChangeDir ${PUBLISH_DIR}
  local NACL_LIB_PATH=$NACL_TOOLCHAIN_ROOT/x86_64-nacl
  local NACL_COMPLEMENT_ARCH="x86_64"
  local NACL_COMPLEMENT_LIBDIR="lib64"
  if [ ${NACL_ARCH} = "x86_64" ]; then
    NACL_COMPLEMENT_ARCH="i686"
    NACL_COMPLEMENT_LIBDIR="lib32"
  fi
  CMD="$NACL_SDK_ROOT/tools/create_nmf.py \
      -L$NACL_LIB_PATH/usr/$NACL_COMPLEMENT_LIBDIR \
      -L$NACL_LIB_PATH/$NACL_COMPLEMENT_LIBDIR \
      -L$NACLPORTS_LIBDIR \
      -L$NACL_SDK_LIB \
      -L$NACL_SDK_LIBDIR \
      -D$NACL_BIN_PATH/x86_64-nacl-objdump \
      -o thttpd.nmf -s . \
      thttpd_${NACL_ARCH}.nexe"

  if [ -f thttpd_${NACL_COMPLEMENT_ARCH}.nexe ]; then
    CMD+=" thttpd_${NACL_COMPLEMENT_ARCH}.nexe"
  fi
  LogExecute $CMD
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
