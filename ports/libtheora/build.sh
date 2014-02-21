#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

ConfigureStep() {
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export PATH=${NACL_BIN_PATH}:${PATH}
  # Turn off doxygen (it doesn't exist on Mac & Linux, and has an error on
  # Windows).
  export HAVE_DOXYGEN="false"
  MakeDir ${BUILD_DIR}
  ChangeDir ${BUILD_DIR}
  ../configure \
    --host=nacl \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    --oldincludedir=${NACLPORTS_INCLUDE} \
    --disable-examples \
    --disable-sdltest \
    --with-http=off \
    --with-html=off \
    --with-ftp=off \
    --with-x=no \
    --${NACL_OPTION}-asm
}
