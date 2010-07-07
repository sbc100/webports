#!/bin/bash
# Copyright (c) 2010 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that be
# found in the LICENSE file.
#

# nacl-gtest-1.5.0.sh
#
# usage:  nacl-gtest-1.5.0.sh
#
# this script downloads, patches, and builds boost for Native Client
#

readonly URL=http://build.chromium.org/mirror/nacl/gtest-1.5.0.tgz
#readonly URL=http://code.google.com/p/googletest/downloads/detail?name=gtest-1.5.0.tar.gz
readonly PATCH_FILE=gtest-1.5.0/nacl-gtest-1.5.0.patch
readonly PACKAGE_NAME=gtest-1.5.0

source ../common.sh

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PATH=${NACL_BIN_PATH}:${PATH};
  export LIB_GTEST=libgtest.a

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
}

CustomInstallStep() {
  Remove ${NACL_SDK_USR_INCLUDE}/gtest
  readonly THIS_PACKAGE_PATH=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  (ChangeDir include; tar cf - --exclude='gtest-death-test.h' --exclude='gtest-death-test-internal.h' gtest | (ChangeDir ${NACL_SDK_USR_INCLUDE}; tar xfp -))
  Remove ${NACL_SDK_USR_LIB}/${LIB_GTEST}
  install --mode=644 ${LIB_GTEST} ${NACL_SDK_USR_LIB}/${LIB_GTEST}
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
