#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-SDL-1.2.14.sh
#
# usage:  nacl-SDL-1.2.14.sh
#
# this script downloads, patches, and builds SDL for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/SDL-1.2.14.tar.gz
# readonly URL=http://www.libsdl.org/release/SDL-1.2.14.tar.gz
readonly PATCH_FILE=SDL-1.2.14/nacl-SDL-1.2.14.patch
readonly PACKAGE_NAME=SDL-1.2.14

source ../../../build_tools/common.sh

export LIBS=-lnosys

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
  ./autogen.sh

  # TODO(khim): remove this when nacl-gcc -V doesn't lockup.
  # See: http://code.google.com/p/nativeclient/issues/detail?id=2074
  TemporaryVersionWorkaround
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}

  Remove ${PACKAGE_NAME}-build
  MakeDir ${PACKAGE_NAME}-build
  cd ${PACKAGE_NAME}-build
  set -x 
  ../configure \
    --host=nacl \
    --disable-assembly \
    --disable-pthread-sem \
    --disable-shared \
    --prefix=${NACL_SDK_USR} \
    --exec-prefix=${NACL_SDK_USR} \
    --libdir=${NACL_SDK_USR_LIB} \
    --oldincludedir=${NACL_SDK_USR_INCLUDE}
  set +x
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
