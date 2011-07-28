#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-gmock-1.5.0.sh
#
# usage:  nacl-gmock-1.5.0.sh
#
# this script downloads, patches, and builds gmock for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/gmock-1.5.0.tgz
#readonly URL=http://googlemock.googlecode.com/files/gmock-1.5.0.tar.gz
readonly PATCH_FILE=gmock-1.5.0/nacl-gmock-1.5.0.patch
readonly PACKAGE_NAME=gmock-1.5.0

source ../../../build_tools/common.sh

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PATH=${NACL_BIN_PATH}:${PATH};
  export LIB_GMOCK=libgmock.a

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
}

CustomInstallStep() {
  Remove ${NACL_SDK_USR_INCLUDE}/gmock
  readonly THIS_PACKAGE_PATH=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  (ChangeDir include; tar cf - gmock | (ChangeDir ${NACL_SDK_USR_INCLUDE}; tar xfp -))
  Remove ${NACL_SDK_USR_LIB}/${LIB_GMOCK}
  install -m 644 ${LIB_GMOCK} ${NACL_SDK_USR_LIB}/${LIB_GMOCK}
  DefaultTouchStep
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
