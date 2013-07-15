#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-ncurses-5.9.sh
#
# usage:  nacl-ncurses-5.9.sh
#
# this script downloads, patches, and builds zlib for Native Client
#

source pkg_info
source ../../build_tools/common.sh


CustomConfigureStep() {
  DefaultConfigureStep --disable-database --with-fallbacks=xterm-256color,vt100
  # Glibc inaccurately reports having sigvec.
  # Change the define
  sed -i.bak 's/HAVE_SIGVEC 1/HAVE_SIGVEC 0/' include/ncurses_cfg.h
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  # ncurses doesn't need patching, so no patch step
  CustomConfigureStep
  DefaultBuildStep
  DefaultInstallStep
}

CustomPackageInstall

exit 0
