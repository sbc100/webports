#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-SDL_image-1.2.10.sh
#
# usage:  nacl-SDL_image-1.2.10.sh
#
# this script downloads, patches, and builds SDL_mixer for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/SDL_image-1.2.10.tar.gz
# readonly URL=http://www.libsdl.org/projects/SDL_image/release/SDL_image-1.2.10.tar.gz
readonly PATCH_FILE=nacl-SDL_image-1.2.10.patch
readonly PACKAGE_NAME=SDL_image-1.2.10

source ../../build_tools/common.sh


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  DefaultConfigureStep
  DefaultBuildStep
  DefaultInstallStep
  DefaultCleanUpStep
}


CustomPackageInstall
exit 0
