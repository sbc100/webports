#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

EXECUTABLES="src/lua src/luac"

CustomBuildStep() {
  Banner "Build ${PACKAGE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  LogExecute make "CC=${NACLCC}" "PLAT=generic" "INSTALL_TOP=${NACLPORTS_PREFIX}" clean
  LogExecute make "CC=${NACLCC}" "PLAT=generic" "INSTALL_TOP=${NACLPORTS_PREFIX}" "MYLIBS=-lnosys" -j ${OS_JOBS}
}


CustomInstallStep() {
  Banner "Install ${PACKAGE_NAME}"

  # TODO: side-by-side install
  LogExecute make "CC=${NACLCC}" "PLAT=generic" "INSTALL_TOP=${NACLPORTS_PREFIX}" install
  cd src
  WriteSelLdrScript lua.sh lua
  WriteSelLdrScript luac.sh luac
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomBuildStep
  DefaultTranslateStep
  DefaultValidateStep
  CustomInstallStep
}


CustomPackageInstall
exit 0
