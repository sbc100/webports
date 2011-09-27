#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-boost_1_47_0.sh
#
# usage:  nacl-boost_1_47_0.sh
#
# this script downloads, patches, and builds boost for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/boost_1_47_0.tar.bz2
#readonly PATCH_FILE=nacl-SDL_net-1.2.7.patch
readonly PACKAGE_NAME=boost_1_47_0

source ../../build_tools/common.sh

CustomConfigureStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  echo "using gcc : 4.4.3 : ${NACLCXX} ;" > tools/build/v2/user-config.jam
}

CustomBuildStep() {
  ./bootstrap.sh

  # TODO(eugenis): build dynamic libraries, too
  if [ $NACL_GLIBC = "1" ] ; then
    ./bjam install \
      --prefix=${NACL_SDK_USR} \
      link=static \
      -d+2 \
      --without-python \
      --without-signals \
      --without-mpi
  else
    ./bjam install \
      --prefix=${NACL_SDK_USR} \
      -d+2 \
      --with-date_time \
      --with-program_options
  fi
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadBzipStep
  DefaultExtractBzipStep
  # No patch needed.
  CustomConfigureStep
  CustomBuildStep
  # Installation is done in the build step.
  DefaultCleanUpStep
}


CustomPackageInstall
exit 0
