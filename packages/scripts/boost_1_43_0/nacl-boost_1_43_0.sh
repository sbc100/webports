#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-boost-1.43.0.sh
#
# usage:  nacl-boost-1.43.0.sh
#
# this script downloads, patches, and builds boost for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/boost_1_43_0.tar.gz
#readonly URL=http://sourceforge.net/projects/boost/files/boost/1.43.0/boost_1_43_0.tar.gz/download
readonly PATCH_FILE=boost_1_43_0/nacl-boost_1_43_0.patch
readonly PACKAGE_NAME=boost_1_43_0

source ../../../build_tools/common.sh

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export LIB_BOOST_DATETIME=libboost_datetime.a
  export LIB_BOOST_PROGRAM_OPTIONS=libboost_program_options.a
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
}

CustomInstallStep() {
  Remove ${NACL_SDK_USR_INCLUDE}/boost
  tar cf - --exclude='asio.hpp' --exclude='asio' --exclude='mpi.hpp' --exclude='mpi' boost | ( ChangeDir ${NACL_SDK_USR_INCLUDE}; tar xfp -)
  Remove ${NACL_SDK_USR_LIB}/${LIB_BOOST_DATETIME}
  install -m 644 ${LIB_BOOST_DATETIME} ${NACL_SDK_USR_LIB}/${LIB_BOOST_DATETIME}
  Remove ${NACL_SDK_USR_LIB}/${LIB_BOOST_PROGRAM_OPTIONS}
  install -m 644 ${LIB_BOOST_PROGRAM_OPTIONS} ${NACL_SDK_USR_LIB}/${LIB_BOOST_PROGRAM_OPTIONS}
}

CustomPackageInstall() {
   DefaultPreInstallStep
   DefaultDownloadStep
   DefaultExtractStep
   DefaultPatchStep
   CustomConfigureStep
   DefaultBuildStep
   CustomInstallStep
   DefaultCleanUpStep
}

CustomPackageInstall
exit 0
