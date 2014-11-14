# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Without these CFLAGS fftw fails to build for ARM
if [ "${NACL_ARCH}" = "arm" ]; then
  NACLPORTS_CPPFLAGS+=" -fomit-frame-pointer -fstrict-aliasing \
  -fno-schedule-insns -ffast-math"

  # Workaround for arm-gcc bug:
  # https://code.google.com/p/nativeclient/issues/detail?id=3205
  # TODO(sbc): remove this once the issue is fixed
  NACLPORTS_CPPFLAGS+=" -mfpu=vfp"
fi

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

TestStep() {
  if [ ${NACL_ARCH} = "pnacl" ]; then
    for arch in x86-32 x86-64; do
      for exe in ${EXECUTABLES}; do
        local exe_noext=${exe%.*}
        WriteSelLdrScriptForPNaCl ${exe_noext} \
            $(basename ${exe_noext}.${arch}.nexe) ${arch}
      done
      make check
    done
  else
    make check
  fi
}

PackageInstall() {
  RunPreInstallStep
  RunDownloadStep
  RunExtractStep
  RunPatchStep

  # Build fftw (double)
  EXECUTABLES="tools/fftw-wisdom${NACL_EXEEXT} tests/bench${NACL_EXEEXT}"
  RunConfigureStep
  RunBuildStep
  RunPostBuildStep
  RunTestStep
  RunInstallStep

  # build fftwf (float)
  EXECUTABLES="tools/fftwf-wisdom${NACL_EXEEXT} tests/bench${NACL_EXEEXT}"
  EXTRA_CONFIGURE_ARGS=--enable-float
  BUILD_DIR+="-float"
  RunConfigureStep
  RunBuildStep
  RunPostBuildStep
  RunTestStep
  RunInstallStep

  PackageStep
}
