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

CustomConfigureStep() {
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
