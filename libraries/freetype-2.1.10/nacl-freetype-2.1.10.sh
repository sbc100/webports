#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-freetype-2.1.10.sh
#
# usage:  nacl-freetype-2.1.10.sh
#
# this script downloads, patches, and builds freetype for Native Client 
#

source pkg_info
source ../../build_tools/common.sh

CustomInstallStep() {
  # do the regular make install
  make install
  # move freetype up a directory so #include <freetype/freetype.h> works...
  Remove ${NACLPORTS_INCLUDE}/freetype
  cp -R ${NACLPORTS_INCLUDE}/freetype2/freetype ${NACLPORTS_INCLUDE}/.
  Remove ${NACLPORTS_INCLUDE}/freetype2
  DefaultTouchStep
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  DefaultConfigureStep
  DefaultBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}


CustomPackageInstall
exit 0

