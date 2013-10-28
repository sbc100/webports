#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh


BuildStep() {
  cd ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  local cflags="${NACLPORTS_CFLAGS}"
  if [ ${NACL_ARCH} != "pnacl" ]; then
    cflags="${cflags} -O3 -fomit-frame-pointer"
  fi
  if [ ${NACL_ARCH} = "i686" -o ${NACL_ARCH} = "x86_64" ]; then
    cflags="${cflags} -mfpmath=sse -msse"
  fi
  MAKEFLAGS="-j${OS_JOBS}" AGGCXXFLAGS="${cflags}" LogExecute make -j${OS_JOBS}
}


InstallStep() {
  # copy libs and headers manually
  ChangeDir ${NACLPORTS_INCLUDE}
  Remove ${PACKAGE_NAME}
  MakeDir ${PACKAGE_NAME}
  readonly THIS_PACKAGE_PATH=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  cp -R ${THIS_PACKAGE_PATH}/include/*.h ${PACKAGE_NAME}/
  cp ${THIS_PACKAGE_PATH}/font_freetype/*.h ${PACKAGE_NAME}/
  ChangeDir ${NACLPORTS_LIBDIR}
  cp ${THIS_PACKAGE_PATH}/src/libagg.a .
  cp ${THIS_PACKAGE_PATH}/font_freetype/libaggfontfreetype.a .
}


PackageInstall
exit 0
