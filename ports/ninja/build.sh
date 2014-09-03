# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}

NACLPORTS_CFLAGS+=" -I${NACLPORTS_INCLUDE}"
NACLPORTS_CXXFLAGS+=" -I${NACLPORTS_INCLUDE}"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  NACLPORTS_CXXFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
fi

ConfigureStep() {
  LogExecute rm -rf build
  LogExecute python bootstrap.py
  cp ninja ninja.host
  SetupCrossEnvironment
  export LIBS+="${NACL_CLI_MAIN_LIB} -lnacl_spawn -lppapi_simple -lnacl_io \
    -lppapi -lppapi_cpp"
  LogExecute python configure.py --host=linux --platform=nacl
}

BuildStep() {
  LogExecute rm -rf build
  LogExecute ./ninja.host
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  MakeDir ${PUBLISH_DIR}/${NACL_ARCH}
  LogExecute cp ${SRC_DIR}/ninja ${PUBLISH_DIR}/${NACL_ARCH}/ninja
  ChangeDir ${PUBLISH_DIR}/${NACL_ARCH}
  LogExecute rm -f ${PUBLISH_DIR}/${NACL_ARCH}.zip
  LogExecute zip -r ${PUBLISH_DIR}/${NACL_ARCH}.zip .
}
