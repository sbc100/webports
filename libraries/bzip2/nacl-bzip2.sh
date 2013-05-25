#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-bzip2-1.0.6.sh
#
# usage:  nacl-bzip2-1.0.6.sh
#
# this script downloads, patches, and builds bzip2 for Native Client
#

source pkg_info
source ../../build_tools/common.sh

CustomConfigureStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
}

CustomBuildStep() {
  make clean
  make CC=${NACLCC} AR=${NACLAR} RANLIB=${NACLRANLIB} -j${OS_JOBS} libbz2.a
  if [ ${NACL_GLIBC} = 1 ]; then
    make -f Makefile-libbz2_so clean
    make -f Makefile-libbz2_so CC=${NACLCC} AR=${NACLAR} \
        RANLIB=${NACLRANLIB} -j${OS_JOBS}
  fi
}

CustomInstallStep() {
  # Don't rely on make install, as it implicitly builds executables
  # that need things not available in newlib.
  LogExecute mkdir -p ${NACLPORTS_PREFIX}/include
  LogExecute cp -f bzlib.h ${NACLPORTS_PREFIX}/include
  LogExecute chmod a+r ${NACLPORTS_PREFIX}/include/bzlib.h

  LogExecute mkdir -p ${NACLPORTS_PREFIX}/lib
  LogExecute cp -f libbz2.a ${NACLPORTS_PREFIX}/lib
  if [ -f libbz2.so.1.0 ]; then
    LogExecute ln -s libbz2.so.1.0 libbz2.so
    LogExecute cp -af libbz2.so* ${NACLPORTS_PREFIX}/lib
  fi
  LogExecute chmod a+r ${NACLPORTS_PREFIX}/lib/libbz2.*

}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  CustomBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}


CustomPackageInstall
exit 0
