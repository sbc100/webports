#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

# Some of the gif command line tools reference 'unlink'
export LIBS='-lnosys'


if [ "${NACL_GLIBC}" = "1" ]; then
  EXECUTABLES=util/.libs/rgb2gif${NACL_EXEEXT}
else
  EXECUTABLES=util/rgb2gif${NACL_EXEEXT}
fi

TestStep() {
  if [ ${NACL_ARCH} = "arm" ]; then
    # no sel_ldr for arm
    return
  fi

  if [ "${NACL_GLIBC}" = "1" ]; then
    # TODO(sbc): find out why glibc version of rgb2gif is crashing
    return
  fi

  if [ $NACL_ARCH = "pnacl" ]; then
    WriteSelLdrScript util/rgb2gif rgb2gif.x86-64.nexe
  elif [ "${NACL_GLIBC}" = "1" ]; then
    WriteSelLdrScript util/rgb2gif .libs/rgb2gif${NACL_EXEEXT}
  else
    WriteSelLdrScript util/rgb2gif rgb2gif${NACL_EXEEXT}
  fi

  util/rgb2gif -s 320 200  < ../tests/porsche.rgb > porsche.gif
  # TODO(sbc): do some basic checks on the resulting porsche.gif
}


CustomBuildStep() {
  Banner "Build ${PACKAGE_NAME}"
  echo "Directory: $(pwd)"
  # Limit the subdirecorties that get built by make. This is to
  # avoid the 'doc' directory which has a dependency on 'xmlto'.
  # If 'xmlto' were added to the host build dependencies this could
  # be removed.
  make -j${OS_JOBS} SUBDIRS="lib util"
}


DefaultPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  DefaultConfigureStep
  CustomBuildStep
  DefaultTranslateStep
  DefaultValidateStep
  DefaultInstallStep
  TestStep
}

DefaultPackageInstall
exit 0
