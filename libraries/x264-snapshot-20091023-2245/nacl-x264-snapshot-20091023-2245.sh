#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# nacl-x264-snapshot-20091023-2245.sh
#
# usage:  nacl-x264-snapshot-20091023-2245.sh
#
# this script downloads, patches, and builds x264 for Native Client
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
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}

  local naclhost
  if [ "${NACL_ARCH}" = pnacl ]; then
    naclhost=pnacl
  else
    naclhost=x86-nacl-linux
  fi

  echo "  ./configure \
    --cross-prefix=${NACL_CROSS_PREFIX} \
    --disable-asm \
    --disable-pthread \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    --extra-ldflags='-lnosys -lm' \
    --host=${naclhost}"

  ./configure \
    --cross-prefix=${NACL_CROSS_PREFIX} \
    --disable-asm \
    --disable-pthread \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    --extra-ldflags="-lnosys -lm" \
    --host=${naclhost}
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadBzipStep
  DefaultExtractBzipStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  DefaultInstallStep
  DefaultCleanUpStep
}


CustomPackageInstall
exit 0
