#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

# Some of the gif command line tools reference 'unlink'
export LIBS='-lnosys'

# Limit the subdirecorties that get built by make. This is to
# avoid the 'doc' directory which has a dependency on 'xmlto'.
# If 'xmlto' were added to the host build dependencies this could
# be removed.
MAKE_TARGETS='SUBDIRS=lib'


TestStep() {
  WriteSelLdrScript util/rgb2gif.sh rgb2gif
  util/rgb2gif.sh -s 320 200  < ../tests/porsche.rgb > porsche.gif
  # TODO(sbc): do some basic checks on the resulting porsche.gif
}


DefaultPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  DefaultConfigureStep
  DefaultBuildStep
  DefaultTranslateStep
  DefaultValidateStep
  DefaultInstallStep
  TestStep
  DefaultCleanUpStep
}

DefaultPackageInstall
exit 0
