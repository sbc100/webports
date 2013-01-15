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

source pkg_info
source ../../build_tools/common.sh

export LIBS=-lnosys

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export CFLAGS="-I${NACL_SDK_ROOT}/include"
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
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
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    --oldincludedir=${NACLPORTS_INCLUDE}
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
