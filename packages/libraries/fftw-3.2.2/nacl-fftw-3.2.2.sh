#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-fftw-3.2.2.sh
#
# usage:  nacl-fftw-3.2.2.sh
#
# This script downloads, patches, and builds fftw-3.2.2 for Native Client.
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/fftw-3.2.2.tar.gz
#readonly URL=http://www.fftw.org/fftw-3.2.2.tar.gz
readonly PATCH_FILE=fftw-3.2.2/fftw-3.2.2.patch
readonly PACKAGE_NAME=fftw-3.2.2

source ../../../build_tools/common.sh

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # Export the nacl tools.
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACL_SDK_USR_LIB}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACL_SDK_USR_LIB}
  export PATH=${NACL_BIN_PATH}:${PATH};
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}

  ./configure --prefix=${NACL_SDK_USR} --host=nacl
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  DefaultInstallStep
  DefaultCleanUpStep
}


CustomPackageInstall
exit 0
