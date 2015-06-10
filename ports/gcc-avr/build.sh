# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

HOST_BUILD_DIR=${WORK_DIR}/build_host
HOST_INSTALL_DIR=${WORK_DIR}/install_host

export EXTRA_LIBS="${NACL_CLI_MAIN_LIB}"
export PATH="${PATH}:${NACL_PACKAGES_BUILD}/binutils-2.25/install_host/bin"

BuildHostGccAvr() {
  MakeDir ${HOST_BUILD_DIR}
  MakeDir ${HOST_INSTALL_DIR}
  ChangeDir ${HOST_BUILD_DIR}
  CC="gcc" EXTRA_LIBS="" \
    LogExecute ${SRC_DIR}/configure \
    --prefix=${NACL_PACKAGES_BUILD}/binutils-2.25/install_host \
    --target=avr \
    --enable-languages=c,c++ \
    --disable-nls --disable-libssp \
    --with-gmp=${NACL_PACKAGES_BUILD}/gmp/install_host \
    --with-mpfr=${NACL_PACKAGES_BUILD}/mpfr/install_host \
    --with-mpc=${NACL_PACKAGES_BUILD}/mpc/install_host
  EXTRA_LIBS="" LogExecute make
  EXTRA_LIBS="" LogExecute make install
}

EXTRA_CONFIGURE_ARGS="\
    --enable-languages=c,c++ --disable-nls \
    --disable-libssp --host=x86_64-nacl --target=avr"

ConfigureStep() {
  for cache_file in $(find . -name config.cache); do
    Remove $cache_file
  done
  ChangeDir ${SRC_DIR}
  BuildHostGccAvr
  ChangeDir ${BUILD_DIR}
  DefaultConfigureStep
}
