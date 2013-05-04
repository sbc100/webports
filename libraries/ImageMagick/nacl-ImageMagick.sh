#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# nacl-ImageMagick-6.5.4-10.sh
#
# usage:  nacl-ImageMagick-6.5.4-10.sh
#
# this script downloads, patches, and builds ImageMagick for Native Client
#

source pkg_info
source ../../build_tools/common.sh

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export PATH=${NACL_BIN_PATH}:${PATH};
  # Drop /opt/X11/bin (may interfere build on osx).
  export PATH=$(echo $PATH | sed -e 's;/opt/X11/bin;;')
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  Remove ${PACKAGE_NAME}-build
  MakeDir ${PACKAGE_NAME}-build
  cd ${PACKAGE_NAME}-build
  ../configure \
    --host=nacl \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    --oldincludedir=${NACLPORTS_INCLUDE} \
    --with-x=no \
    --disable-largefile \
    --without-fftw
}


CustomBuildAndInstallStep() {
  # assumes pwd has makefile
  make clean
  cflags="${NACLPORTS_CFLAGS} -DSSIZE_MAX=\"((ssize_t)(~((size_t)0)>>1))\""
  make CFLAGS="${cflags}" install-libLTLIBRARIES install-data-am -j${OS_JOBS}
  DefaultTouchStep
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  CustomBuildAndInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
