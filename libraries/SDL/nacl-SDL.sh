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

AutogenStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  # For some reason if we don't remove configure before running
  # autoconf it doesn't always get updates correctly.  About half
  # the time the old configure script (with no reference to nacl)
  # will remain after ./autogen.sh
  rm configure
  ./autogen.sh
  PatchConfigure
  PatchConfigSub
}

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}

  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export PATH=${NACL_BIN_PATH}:${PATH};

  # LIBS and LDFLAGS are needed when linking the shared library.
  export LIBS="-lppapi_cpp"
  export LDFLAGS="$LDFLAGS -Wl,--as-needed"

  Remove build-nacl
  MakeDir build-nacl
  cd build-nacl

  set -x
  LogExecute ../configure \
    --host=nacl \
    --disable-assembly \
    --disable-pthread-sem \
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
  AutogenStep
  CustomConfigureStep
  DefaultBuildStep
  DefaultInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
