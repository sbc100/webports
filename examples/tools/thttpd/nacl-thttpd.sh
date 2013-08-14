#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

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
  for FILE in $FILES; do
    cp -f ${START_DIR}/${FILE} .
  done

  LogExecute make -j${OS_JOBS} clean
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
  LogExecute make -j${OS_JOBS} thttpd
}

CustomInstallStep() {
  Banner "Installing ${PACKAGE_NAME}"
  local PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}
  install ${START_DIR}/thttpd.html ${PUBLISH_DIR}
  install ${START_DIR}/nacl.js ${PUBLISH_DIR}
  install ${START_DIR}/peppermount_helper.js ${PUBLISH_DIR}
  install ${START_DIR}/json2min.js ${PUBLISH_DIR}
  BUILD_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  cp ${BUILD_DIR}/thttpd ${BUILD_DIR}/thttpd_${NACL_ARCH}${NACL_EXEEXT}
  install ${BUILD_DIR}/thttpd_${NACL_ARCH}${NACL_EXEEXT} ${PUBLISH_DIR}/
  ChangeDir ${PUBLISH_DIR}

  CMD="$NACL_SDK_ROOT/tools/create_nmf.py \
       $NACL_CREATE_NMF_FLAGS
      -o thttpd.nmf -s . \
      thttpd_*${NACL_EXEEXT}"

  ChangeDir ${PACKAGE_DIR}
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
}

CustomPackageInstall
exit 0
