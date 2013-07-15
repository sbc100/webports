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

source pkg_info
source ../../build_tools/common.sh

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  DefaultConfigureStep --disable-esd
  DefaultBuildStep
  DefaultInstallStep
}

CustomPackageInstall
exit 0
