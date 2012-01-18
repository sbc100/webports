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

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/jsoncpp-src-0.5.0.tar.gz
#readonly URL=http://citylan.dl.sourceforge.net/project/jsoncpp/jsoncpp/0.5.0/jsoncpp-src-0.5.0.tar.gz
readonly PATCH_FILE=
readonly PACKAGE_NAME=jsoncpp-src-0.5.0

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
  cp ${PACKAGE_DIR}/libjsoncpp.a ${NACL_SDK_USR_LIB}
  cp -R ${PACKAGE_DIR}/include/json ${NACL_SDK_USR_INCLUDE}
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
