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


CustomBuildAndInstallStep() {
  # assumes pwd has makefile
  LogExecute make clean
  cflags="${NACLPORTS_CFLAGS} -DSSIZE_MAX='((ssize_t)(~((size_t)0)>>1))'"
  # Adding -j${OS_JOBS} here causes occational failures when
  # shared libraries are being built.
  make CFLAGS="${cflags}" install-libLTLIBRARIES install-data-am
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  CustomBuildAndInstallStep
}

CustomPackageInstall
exit 0
