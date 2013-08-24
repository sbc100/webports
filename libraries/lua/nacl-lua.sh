#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

EXECUTABLES="src/lua src/luac"

BuildStep() {
  Banner "Build ${PACKAGE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  if [ "${NACL_GLIBC}" = "1" ]; then
    PLAT=nacl-glibc
  else
    PLAT=nacl-newlib
  fi
  LogExecute make "CC=${NACLCC}" "PLAT=${PLAT}" "INSTALL_TOP=${NACLPORTS_PREFIX}" clean
  LogExecute make "CC=${NACLCC}" "PLAT=${PLAT}" "INSTALL_TOP=${NACLPORTS_PREFIX}" -j${OS_JOBS}
}


InstallStep() {
  Banner "Install ${PACKAGE_NAME}"

  # TODO: side-by-side install
  LogExecute make "CC=${NACLCC}" "PLAT=generic" "INSTALL_TOP=${NACLPORTS_PREFIX}" install
  cd src
  WriteSelLdrScript lua.sh lua
  WriteSelLdrScript luac.sh luac
}


PackageInstall
exit 0
