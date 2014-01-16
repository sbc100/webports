#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}

ConfigureStep() {
  local EXTRA_CONFIGURE_OPTS=("${@:-}")
  Banner "Configuring ${PACKAGE_NAME}"
  # Export the nacl tools.
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export PATH=${NACL_BIN_PATH}:${PATH};
  extra="--enable-threads"
  if [ ${NACL_ARCH} = "x86_64" -o ${NACL_ARCH} = "i686" ]; then
    extra="${extra} --enable-sse2"
  fi

  LogExecute ./configure \
    --host=nacl \
    --prefix=${NACLPORTS_PREFIX} \
    ${EXTRA_CONFIGURE_OPTS[@]} \
    ${extra}
}

PackageInstall() {
  PreInstallStep
  DownloadStep
  ExtractStep
  PatchStep

  # Build fftw (double)
  EXECUTABLES=tools/fftw-wisdom${NACL_EXEEXT}
  ConfigureStep
  BuildStep
  InstallStep
  TranslateStep
  ValidateStep

  # build fftwf (float)
  EXECUTABLES=tools/fftwf-wisdom${NACL_EXEEXT}
  ConfigureStep --enable-float
  BuildStep
  InstallStep
  TranslateStep
  ValidateStep
}
