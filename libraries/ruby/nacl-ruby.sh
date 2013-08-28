#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

if [ ${NACL_GLIBC} != 1 ]; then
  EXTRA_CONFIGURE_ARGS=--with-static-linked-ext
  export LIBS=-lnosys
fi

MAKE_TARGETS="pprogram"
INSTALL_TARGETS="install-nodoc DESTDIR=${NACL_TOOLCHAIN_INSTALL}"
EXECUTABLES="ruby.nexe pepper-ruby.nexe"

ConfigureStep() {
  # We need to build a host version of ruby for use during the nacl
  # build.
  HOST_BUILD=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/build-nacl-host
  if [ ! -x ${HOST_BUILD}/miniruby ]; then
    MakeDir ${HOST_BUILD}
    ChangeDir ${HOST_BUILD}
    LogExecute ../configure
    LogExecute make -j${OS_JOBS} miniruby
  fi
  export MINIRUBY='`cd $(srcdir); pwd`/build-nacl-host/miniruby -I`cd $(srcdir)/lib; pwd` -I.'

  local EXTRA_CONFIGURE_OPTS=("${@:-}")
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export FREETYPE_CONFIG=${NACLPORTS_PREFIX_BIN}/freetype-config
  export PATH=${NACL_BIN_PATH}:${PATH};
  local SRC_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  if [ ! -f "${SRC_DIR}/configure" ]; then
    echo "No configure script found"
    return
  fi
  local DEFAULT_BUILD_DIR=${SRC_DIR}/${NACL_BUILD_SUBDIR}
  local BUILD_DIR=${NACL_BUILD_DIR:-${DEFAULT_BUILD_DIR}}
  MakeDir ${BUILD_DIR}
  ChangeDir ${BUILD_DIR}
  echo "Directory: $(pwd)"

  local conf_host=${NACL_CROSS_PREFIX}
  if [ ${NACL_ARCH} = "pnacl" ]; then
    # The PNaCl tools use "pnacl-" as the prefix, but config.sub
    # does not know about "pnacl".  It only knows about "le32-nacl".
    # Unfortunately, most of the config.subs here are so old that
    # it doesn't know about that "le32" either.  So we just say "nacl".
    conf_host="nacl"
  fi
  LogExecute ${NACL_CONFIGURE_PATH:-../configure} \
    --host=${conf_host} \
    --prefix=/usr \
    --oldincludedir=${NACLPORTS_INCLUDE} \
    --with-http=no \
    --with-html=no \
    --with-ftp=no \
    --${NACL_OPTION}-mmx \
    --${NACL_OPTION}-sse \
    --${NACL_OPTION}-sse2 \
    --${NACL_OPTION}-asm \
    --with-x=no  \
    "${EXTRA_CONFIGURE_OPTS[@]}" ${EXTRA_CONFIGURE_ARGS:-}
}

BuildStep() {
  DefaultBuildStep
  WriteSelLdrScript ruby ruby.nexe
}

PackageInstall
exit 0
