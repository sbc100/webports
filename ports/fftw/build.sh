#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

ConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  MakeDir ${BUILD_DIR}
  ChangeDir ${BUILD_DIR}
  # Export the nacl tools.
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export PATH=${NACL_BIN_PATH}:${PATH};
  local extra=""
  if [ ${NACL_ARCH} = "x86_64" -o ${NACL_ARCH} = "i686" ]; then
    extra="--enable-sse2"
  fi

  LogExecute ../configure \
    --host=nacl \
    --prefix=${NACLPORTS_PREFIX} \
    --enable-threads \
    ${EXTRA_CONFIGURE_ARGS:-} \
    ${extra}
}

PackageInstall() {
  RunPreInstallStep
  RunDownloadStep
  RunExtractStep
  RunPatchStep

  # Build fftw (double)
  EXECUTABLES=tools/fftw-wisdom${NACL_EXEEXT}
  RunConfigureStep
  RunBuildStep
  RunInstallStep
  RunTranslateStep
  RunValidateStep

  # build fftwf (float)
  EXECUTABLES=tools/fftwf-wisdom${NACL_EXEEXT}
  EXTRA_CONFIGURE_ARGS=--enable-float
  BUILD_DIR+="-float"
  RunConfigureStep
  RunBuildStep
  RunInstallStep
  RunTranslateStep
  RunValidateStep
}
