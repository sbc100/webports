#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-openal-soft-1.13.sh
#
# usage:  nacl-openal-soft-1.13.sh
#
# this script downloads, patches, and builds OpenAL for Native Client
#

source pkg_info
source ../../build_tools/common.sh

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"

  # Defaults to dynamic lib, but newlib can only link statically.
  LIB_ARG=
  if [[ ${NACL_GLIBC} = 0 ]]; then
    LIB_ARG="-DLIBTYPE=STATIC"
  fi

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  Remove ${NACL_BUILD_SUBDIR}
  MakeDir ${NACL_BUILD_SUBDIR}
  cd ${NACL_BUILD_SUBDIR}
  CC="${NACLCC}" CXX="${NACLCXX}" cmake .. \
      -DCMAKE_TOOLCHAIN_FILE=../XCompile-nacl.txt \
      -DNACLAR=${NACLAR} \
      -DNACL_CROSS_PREFIX=${NACL_CROSS_PREFIX} \
      -DNACL_SDK_ROOT=${NACL_SDK_ROOT} \
      -DCMAKE_INSTALL_PREFIX=${NACLPORTS_PREFIX} \
      ${LIB_ARG}

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

