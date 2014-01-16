#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}

ConfigureStep() {
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
  ChangeDir ${BUILD_DIR}
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


InstallStep() {
  # assumes pwd has makefile
  make install
}
