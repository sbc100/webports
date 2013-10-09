#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

# TODO: Remove when this is fixed.
# https://code.google.com/p/nativeclient/issues/detail?id=3205
if [ "$NACL_ARCH" = "arm" ]; then
  export NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS//-O2/}"
fi

ConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export CFLAGS=${NACLPORTS_CFLAGS}
  export CXXFLAGS=${NACLPORTS_CXXFLAGS}
  export LDFLAGS=${NACLPORTS_LDFLAGS}
  export PATH=${NACL_BIN_PATH}:${PATH};
  # Drop /opt/X11/bin (may interfere build on osx).
  export PATH=$(echo $PATH | sed -e 's;/opt/X11/bin;;')
  LDFLAGS+=" -Wl,--as-needed"
  export LDFLAGS
  MakeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}/${NACL_BUILD_SUBDIR}
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}/${NACL_BUILD_SUBDIR}

  local conf_host=${NACL_CROSS_PREFIX}
  if [ ${NACL_ARCH} = "pnacl" ]; then
    # The PNaCl tools use "pnacl-" as the prefix, but config.sub
    # does not know about "pnacl".  It only knows about "le32-nacl".
    # Unfortunately, most of the config.subs here are so old that
    # it doesn't know about that "le32" either.  So we just say "nacl".
    conf_host="nacl"
  fi

  LogExecute ../configure \
    --host=${conf_host} \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    --oldincludedir=${NACLPORTS_INCLUDE} \
    --with-x=no \
    --disable-largefile \
    --without-fftw
}


BuildAndInstallStep() {
  # assumes pwd has makefile
  LogExecute make clean
  cflags="${NACLPORTS_CFLAGS} -DSSIZE_MAX='((ssize_t)(~((size_t)0)>>1))'"
  # Adding -j${OS_JOBS} here causes occational failures when
  # shared libraries are being built.
  make CFLAGS="${cflags}" install-libLTLIBRARIES install-data-am
}


PackageInstall() {
  PreInstallStep
  DownloadStep
  ExtractStep
  PatchStep
  ConfigureStep
  BuildAndInstallStep
}


PackageInstall
exit 0
