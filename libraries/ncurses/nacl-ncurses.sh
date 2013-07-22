#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

EXTRA_CONFIGURE_ARGS="--disable-database"
EXTRA_CONFIGURE_ARGS+=" --with-fallbacks=xterm-256color,vt100"
EXTRA_CONFIGURE_ARGS+=" --disable-termcap"
# Without this ncurses headers will be installed include/ncurses
EXTRA_CONFIGURE_ARGS+=" --enable-overwrite"

if [ "${NACL_GLIBC}" = 1 ]; then
  EXTRA_CONFIGURE_ARGS+=" --with-shared"
fi

if [[ "${NACL_ARCH}" = "pnacl" ]] ; then
  EXTRA_CONFIGURE_ARGS+=" --without-cxx-binding"
fi

CustomConfigureStep() {
  if [[ "${NACL_GLIBC}" != "1" ]]; then
    readonly GLIBC_COMPAT=${NACLPORTS_INCLUDE}/glibc-compat
    # Changing NACLCC rather than CFLAGS as otherwise the configure script
    # fails to detect termios and tries to use gtty.
    NACLCC+=" -I${GLIBC_COMPAT}"
    export LIBS="-lglibc-compat -lnosys"
  fi

  DefaultConfigureStep
  # Glibc inaccurately reports having sigvec.
  # Change the define
  sed -i.bak 's/HAVE_SIGVEC 1/HAVE_SIGVEC 0/' include/ncurses_cfg.h
}


CustomInstallStep() {
  DefaultInstallStep
  cd ${NACLPORTS_LIBDIR}
  ln -sf libncurses.a libtermcap.a
  cd -
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  CustomInstallStep
}

CustomPackageInstall

exit 0
