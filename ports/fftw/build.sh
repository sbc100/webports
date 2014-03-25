#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Without these CFLAGS fftw fails to build for ARM
NACLPORTS_CFLAGS+=" -fomit-frame-pointer -fstrict-aliasing \
  -fno-schedule-insns -ffast-math"

ConfigureStep() {
  SetupCrossEnvironment

  local extra=""
  if [ ${NACL_ARCH} = "x86_64" -o ${NACL_ARCH} = "i686" ]; then
    extra="--enable-sse2"
  fi

  LogExecute ${SRC_DIR}/configure \
    --host=nacl \
    --prefix=${PREFIX} \
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
  RunPostBuildStep
  RunInstallStep

  # build fftwf (float)
  EXECUTABLES=tools/fftwf-wisdom${NACL_EXEEXT}
  EXTRA_CONFIGURE_ARGS=--enable-float
  BUILD_DIR+="-float"
  RunConfigureStep
  RunBuildStep
  RunPostBuildStep
  RunInstallStep

  PackageStep
}
