#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-Mesa-7.6.sh
#
# usage:  nacl-Mesa-7.6.sh
#
# this script downloads, patches, and builds Mesa for Native Client
#

source pkg_info
source ../../build_tools/common.sh

CustomConfigureStep() {
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export LD=${NACLLD}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_PREFIX}/lib/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_PREFIX}/lib
  export PATH=${NACL_BIN_PATH}:${PATH};
  export X11_INCLUDES=
  cd ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  ./configure \
    --host=nacl \
    --enable-static \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_PREFIX}/lib \
    --oldincludedir=${NACLPORTS_PREFIX}/include \
    --datarootdir=${NACLPORTS_PREFIX} \
    --disable-gl-osmesa \
    --with-x=no \
    --with-driver=osmesa \
    --disable-asm \
    --disable-glut \
    --disable-gallium \
    --disable-egl \
    --disable-glw
}


CustomInstallStep() {
  # assumes pwd has makefile
  make install
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
