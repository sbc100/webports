#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-SDL_ttf-2.0.10.sh
#
# usage:  nacl-SDL_ttf-2.0.10.sh
#
# this script downloads, patches, and builds SDL_mixer for Native Client
#

source pkg_info
source ../../build_tools/common.sh


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  DefaultConfigureStep
  DefaultBuildStep
  DefaultInstallStep
}


CustomPackageInstall
exit 0
