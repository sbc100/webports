#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-gc6.8.sh
#
# usage:  nacl-gc6.8.sh
#
# this script downloads, patches, and builds libgc for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/gc6.8.tar.gz
#readonly URL=http://www.hpl.hp.com/personal/Hans_Boehm/gc/gc_source/gc6.8.tar.gz
readonly PATCH_FILE=gc6.8/nacl-gc6.8.patch
readonly PACKAGE_NAME=gc6.8

source ../../../build_tools/common.sh

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
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  Remove ${PACKAGE_NAME}-build
  MakeDir ${PACKAGE_NAME}-build
  cd ${PACKAGE_NAME}-build
  ../configure \
    --host=nacl \
    --disable-shared \
    --prefix=${NACL_SDK_USR} \
    --exec-prefix=${NACL_SDK_USR} \
    --libdir=${NACL_SDK_USR_LIB} \
    --oldincludedir=${NACL_SDK_USR_INCLUDE} \
    --with-http=off \
    --with-html=off \
    --with-ftp=off \
    --enable-threads=pthreads \
    --${NACL_OPTION}-mmx \
    --${NACL_OPTION}-sse \
    --${NACL_OPTION}-sse2 \
    --${NACL_OPTION}-asm \
    --with-x=no
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

