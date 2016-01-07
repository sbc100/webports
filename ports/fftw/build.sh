# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="tools/fftw-wisdom${NACL_EXEEXT} tests/bench${NACL_EXEEXT}"

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

  if [ ${NACL_ARCH} = "x86_64" -o ${NACL_ARCH} = "i686" ]; then
    EXTRA_CONFIGURE_ARGS+=" --enable-sse2"
  fi

  LogExecute ${SRC_DIR}/configure \
    --host=nacl \
    --prefix=${PREFIX} \
    --enable-threads \
    ${EXTRA_CONFIGURE_ARGS:-}
}

TestStep() {
  LogExecute make check EXEEXT=

  if [ ${NACL_ARCH} = "pnacl" ]; then
    for arch in x86-32 arm; do
      for exe in ${EXECUTABLES}; do
        local exe_noext=${exe%.*}
        WriteLauncherScript ${exe_noext} $(basename ${exe_noext}.${arch}.nexe)
      done
      LogExecute make check EXEEXT=
    done
  fi
}
