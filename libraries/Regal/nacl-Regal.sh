#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

# override the extract step since the github generated tarball
# puts all the files in regal-SHA1HASH folder
CustomExtractStep() {
  ArchiveName
  Banner "Untaring ${ARCHIVE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  Remove ${PACKAGE_NAME}
  MakeDir ${PACKAGE_NAME}
  ChangeDir ${PACKAGE_NAME}
  local tarball=${NACL_PACKAGES_TARBALLS}/${ARCHIVE_NAME}
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
  cp -a lib/nacl-${NACL_ARCH}/libRegal*.a ${NACLPORTS_LIBDIR}
  if [ "${NACL_GLIBC}" = 1 ]; then
    cp -a lib/nacl-${NACL_ARCH}/libRegal*.so* ${NACLPORTS_LIBDIR}
  fi
  cp -r include/GL ${NACLPORTS_INCLUDE}
}


DefaultPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  CustomExtractStep
  DefaultPatchStep
  CustomBuildStep
  CustomInstallStep
}

DefaultPackageInstall
exit 0
