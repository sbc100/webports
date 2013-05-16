#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

# override the extract step since the github generated tarball
# puts all the files in regal-SHA1HASH folder
CustomExtractStep() {
  local tarball=${NACL_PACKAGES_TARBALLS}/${PACKAGE_NAME}.tgz
  Banner "Untaring ${PACKAGE_NAME}.tgz"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  Remove ${PACKAGE_NAME}
  MakeDir ${PACKAGE_NAME}
  ChangeDir ${PACKAGE_NAME}
  if [ $OS_SUBDIR = "windows" ]; then
    tar --strip-components=1 --no-same-owner -zxf ${tarball}
  else
    tar --strip-components=1 -zxf ${tarball}
  fi
}


CustomBuildStep() {
  Banner "Build ${PACKAGE_NAME}"
  cd ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  make -f Makefile SYSTEM=nacl-${NACL_ARCH}
}


CustomInstallStep() {
  Banner "Install ${PACKAGE_NAME}"
  cp lib/nacl-${NACL_ARCH}/libRegal*.a ${NACLPORTS_LIBDIR}
  cp -r include/GL ${NACLPORTS_INCLUDE}
  DefaultTouchStep
}


DefaultPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  CustomExtractStep
  CustomBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}

DefaultPackageInstall
exit 0
