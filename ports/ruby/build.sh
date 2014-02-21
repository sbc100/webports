#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

MAKE_TARGETS="pprogram"
INSTALL_TARGETS="install-nodoc DESTDIR=${NACL_TOOLCHAIN_INSTALL}"

EXECUTABLES="ruby${NACL_EXEEXT} pepper-ruby${NACL_EXEEXT}"

ConfigureStep() {
  # We need to build a host version of ruby for use during the nacl
  # build.
  HOST_BUILD=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/build-nacl-host
  if [ ! -x ${HOST_BUILD}/inst/bin/ruby ]; then
    Banner "Building ruby for host"
    MakeDir ${HOST_BUILD}
    ChangeDir ${HOST_BUILD}
    CFLAGS="" LDFLAGS="" LogExecute ../configure --prefix=$PWD/inst
    LogExecute make -j${OS_JOBS} miniruby
    LogExecute make -j${OS_JOBS} install-nodoc
  fi

  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export FREETYPE_CONFIG=${NACLPORTS_PREFIX_BIN}/freetype-config
  export CFLAGS=${NACLPORTS_CFLAGS}
  export CXXFLAGS=${NACLPORTS_CXXFLAGS}
  export CPPFLAGS=${NACLPORTS_CPPFLAGS}
  export LDFLAGS=${NACLPORTS_LDFLAGS}
  export PATH=${NACL_BIN_PATH}:${PATH}
  if [ ! -f "${SRC_DIR}/configure" ]; then
    echo "No configure script found"
    return
  fi
  MakeDir ${BUILD_DIR}
  ChangeDir ${BUILD_DIR}

  # TODO(sbc): remove once getaddrinfo() is working
  local EXTRA_CONFIGURE_ARGS=--disable-ipv6

  if [ ${NACL_GLIBC} != 1 ]; then
    EXTRA_CONFIGURE_ARGS+=" --with-static-linked-ext --with-newlib"
    export LIBS="-lglibc-compat"
  else
    EXTRA_CONFIGURE_ARGS+=" --with-out-ext=openssl,digest/*"
  fi

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
    --prefix=/usr \
    --oldincludedir=${NACLPORTS_INCLUDE} \
    --with-baseruby=$SRC_DIR/build-nacl-host/inst/bin/ruby \
    --with-http=no \
    --with-html=no \
    --with-ftp=no \
    --${NACL_OPTION}-mmx \
    --${NACL_OPTION}-sse \
    --${NACL_OPTION}-sse2 \
    --${NACL_OPTION}-asm \
    --with-x=no  \
    ${EXTRA_CONFIGURE_ARGS}
}

BuildStep() {
  DefaultBuildStep
  if [ $NACL_ARCH == "pnacl" ]; then
    # Just write the x86-64 version out for now.
    TranslateAndWriteSelLdrScript ruby.pexe x86-64 ruby.x86-64.nexe ruby
  fi
}
