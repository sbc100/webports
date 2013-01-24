#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-jpeg-6b.sh
#
# usage:  nacl-jpeg-6b.sh
#
# this script downloads, patches, and builds libjpeg for Native Client 
#

source pkg_info
source ../../build_tools/common.sh


CustomInstallStep() {
  make install-lib
  make install-headers
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
