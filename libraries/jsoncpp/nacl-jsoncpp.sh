#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh


CustomBuildStep() {
  Banner "Building ${PACKAGE_NAME}"
  export PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  ChangeDir ${PACKAGE_DIR}

  export CXXCMD="${NACLCC} -Iinclude -I."
  LogExecute ${CXXCMD} -c src/lib_json/json_reader.cpp
  LogExecute ${CXXCMD} -c src/lib_json/json_value.cpp
  LogExecute ${CXXCMD} -c src/lib_json/json_writer.cpp

  LogExecute ${NACLAR} rcs libjsoncpp.a \
    json_reader.o \
    json_value.o \
    json_writer.o

  LogExecute ${NACLRANLIB} libjsoncpp.a
}


CustomInstallStep() {
  Banner "Installing ${PACKAGE_NAME}"
  export PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"

  LogExecute cp ${PACKAGE_DIR}/libjsoncpp.a ${NACLPORTS_LIBDIR}
  LogExecute cp -R ${PACKAGE_DIR}/include/json ${NACLPORTS_INCLUDE}
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  CustomBuildStep
  CustomInstallStep
}

CustomPackageInstall
exit 0
