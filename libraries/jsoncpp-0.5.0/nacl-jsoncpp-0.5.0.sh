#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-jsoncpp-0.5.0.sh
#
# usage:  nacl-jsoncpp-0.5.0.sh
#
# this script downloads, patches, and builds jsoncpp for Native Client
#

source pkg_info
source ../../build_tools/common.sh


CustomBuildStep() {
  Banner "Building ${PACKAGE_NAME}"
  export PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  ChangeDir ${PACKAGE_DIR}

  export CXXCMD="${NACLCC} -Iinclude -I."
  set -x
  ${CXXCMD} -c src/lib_json/json_reader.cpp
  ${CXXCMD} -c src/lib_json/json_value.cpp
  ${CXXCMD} -c src/lib_json/json_writer.cpp

  ${NACLAR} rcs libjsoncpp.a \
    json_reader.o \
    json_value.o \
    json_writer.o

  ${NACLRANLIB} libjsoncpp.a
  set +x
}


CustomInstallStep() {
  Banner "Installing ${PACKAGE_NAME}"
  export PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"

  set -x
  cp ${PACKAGE_DIR}/libjsoncpp.a ${NACLPORTS_LIBDIR}
  cp -R ${PACKAGE_DIR}/include/json ${NACLPORTS_INCLUDE}
  set +x
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  CustomBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
