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

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/ncurses-5.9.tar.gz
#readonly URL=ftp://ftp.gnu.org/gnu/ncurses/ncurses-5.9.tar.gz
readonly PATCH_FILE=
readonly PACKAGE_NAME=ncurses-5.9

source ../../build_tools/common.sh


CustomConfigureStep() {
  DefaultConfigureStep --disable-database --with-fallbacks=xterm-256color,vt100
  # Glibc inaccurately reports having sigvec.
  # Change the define
  sed -i 's/HAVE_SIGVEC 1/HAVE_SIGVEC 0/' include/ncurses_cfg.h
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  # ncurses doesn't need patching, so no patch step
  CustomConfigureStep
  DefaultBuildStep
  DefaultInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall

exit 0
