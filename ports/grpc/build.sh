# Copyright 2016 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

NACLPORTS_CPPFLAGS+=" -D_POSIX_TIMERS"
EnableGlibcCompat

ConfigureStep() {
  LogExecute cp -r ${SRC_DIR}/* .
}

SetupEnv() {
  SetupCrossEnvironment
  export DEFAULT_CC=${CC}
  export DEFAULT_CXX=${CXX}
  export SYSTEM=nacl
  export PATH=${PATH}:${BUILD_DIR}/../../protobuf/build_host/src/
  export LDLIBS=${LIBS}
  unset LIBS
}

BuildStep() {
  SetupEnv
  DefaultBuildStep
}

InstallStep() {
  SetupEnv
  LogExecute make install prefix=${DESTDIR}/${PREFIX}
}
