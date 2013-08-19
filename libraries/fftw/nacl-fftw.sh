#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

# TODO: Remove when this is fixed.
# https://code.google.com/p/nativeclient/issues/detail?id=3205
if [ "$NACL_ARCH" = "arm" ]; then
  export CFLAGS="${CFLAGS//-O2/}"
fi

ConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # Export the nacl tools.
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export PATH=${NACL_BIN_PATH}:${PATH};
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  extra=
  if [ ${NACL_ARCH} = "x86_64" -o ${NACL_ARCH} = "i686" ] ; then
    extra="--enable-sse2"
  fi

  LogExecute ./configure --prefix=${NACLPORTS_PREFIX} --host=nacl ${extra}
}


PackageInstall
exit 0
