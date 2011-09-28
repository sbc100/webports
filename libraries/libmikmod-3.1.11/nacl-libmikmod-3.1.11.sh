#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-libmikmod-3.1.11.sh
#
# usage:  nacl-libmikmod-3.1.11.sh
#
# this script downloads, patches, and builds SDL_mixer for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/libmikmod-3.1.11.tar.gz
# readonly URL=http://mikmod.raphnet.net/files/libmikmod-3.1.11.tar.gz
readonly PATCH_FILE=nacl-libmikmod-3.1.11.patch
readonly PACKAGE_NAME=libmikmod-3.1.11

source ../../build_tools/common.sh

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  DefaultConfigureStep --disable-esd
  DefaultBuildStep
  DefaultInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
