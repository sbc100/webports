#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

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
  # Add chmod here since gtest archive contains readonly files we don't
  # want installed files to be readonly
  LogExecute chmod -R +w .

  Remove ${NACLPORTS_LIBDIR}/${LIB_GTEST}
  LogExecute install -m 644 ${LIB_GTEST} ${NACLPORTS_LIBDIR}/${LIB_GTEST}

  Remove ${NACLPORTS_INCLUDE}/gtest
  LogExecute cp -r include/gtest ${NACLPORTS_INCLUDE}/gtest

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
