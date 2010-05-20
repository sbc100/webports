#!/bin/bash
# Copyright (c) 2010 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that be
# found in the LICENSE file.
#

# nacl-boost-1.43.0.sh
#
# usage:  nacl-boost-1.43.0.sh
#
# this script downloads, patches, and builds boost for Native Client
#

readonly URL=http://build.chromium.org/mirror/nacl/boost_1_43_0.tar.gz
#readonly URL=http://sourceforge.net/projects/boost/files/boost/1.43.0/boost_1_43_0.tar.gz/download
readonly PATCH_FILE=boost_1_43_0/nacl-boost_1_43_0.patch
readonly PACKAGE_NAME=boost_1_43_0

source ../common.sh

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACL_SDK_USR_LIB}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACL_SDK_USR_LIB}
  export PATH=${NACL_BIN_PATH}:${PATH};
  export NACL_INCLUDE=${NACL_SDK_USR_INCLUDE}
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
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
