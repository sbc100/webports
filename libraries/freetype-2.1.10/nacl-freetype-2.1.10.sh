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

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/freetype-2.1.10.tar.gz
#readonly URL=http://download.savannah.gnu.org/releases/freetype/freetype-2.1.10.tar.gz
readonly PATCH_FILE=nacl-freetype-2.1.10.patch
readonly PACKAGE_NAME=freetype-2.1.10

source ../../build_tools/common.sh

CustomInstallStep() {
  # do the regular make install
  make install
  # move freetype up a directory so #include <freetype/freetype.h> works...
  Remove ${NACL_SDK_USR_INCLUDE}/freetype
  cp -R ${NACL_SDK_USR_INCLUDE}/freetype2/freetype ${NACL_SDK_USR_INCLUDE}/.
  Remove ${NACL_SDK_USR_INCLUDE}/freetype2
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

