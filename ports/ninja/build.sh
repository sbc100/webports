# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="ninja"

LIBS+="${NACL_CLI_MAIN_LIB} -lppapi_simple -lnacl_io \
    -lppapi -lppapi_cpp"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  LIBS+=" -lglibc-compat"
fi

BuildHostNinja() {
  # Build a host version ninja in $SRC_DIR
  if [ -f "${SRC_DIR}/ninja" ];then
    return
  fi
  ChangeDir ${SRC_DIR}
  LogExecute python ./configure.py --bootstrap
  ChangeDir ${BUILD_DIR}
}

ConfigureStep() {
  BuildHostNinja
  SetupCrossEnvironment
  # ninja doesn't honor CPPFLAGS to add them to CFLAGS
  export LIBS
  CFLAGS+=" ${CPPFLAGS}"
  LogExecute python ${SRC_DIR}/configure.py --host=linux --platform=nacl
}

BuildStep() {
  LogExecute ${SRC_DIR}/ninja
}

TestStep() {
  LogExecute ${SRC_DIR}/ninja ninja_test
  RunSelLdrCommand ninja_test --gtest_filter=-SubprocessTest.*
}

InstallStep() {
  return
}

PublishStep() {
  MakeDir ${PUBLISH_DIR}
  MakeDir ${PUBLISH_DIR}/${NACL_ARCH}
  LogExecute cp ninja ${PUBLISH_DIR}/${NACL_ARCH}/ninja
  PublishByArchForDevEnv
}
