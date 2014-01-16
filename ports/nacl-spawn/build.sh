#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BuildStep() {
  Banner "Building ${PACKAGE_NAME}"
  MakeDir ${BUILD_DIR}
  ChangeDir ${BUILD_DIR}
  if [ "${NACL_GLIBC}" = "1" ]; then
    NACLPORTS_CFLAGS+=" -fPIC"
  fi

  local OBJECTS="nacl_spawn.o"
  set -x
  NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS} -I${START_DIR}/.. -I${START_DIR}"
  CCCMD="${NACLCC} ${NACLPORTS_CFLAGS}"
  CXXCMD="${NACLCXX} ${NACLPORTS_CFLAGS}"

  ${CXXCMD} -c ${START_DIR}/nacl_spawn.cc
  ${NACLAR} rcs libnacl_spawn.a ${OBJECTS}
  ${NACLRANLIB} libnacl_spawn.a
  if [ "${NACL_GLIBC}" = "1" ]; then
    ${NACLCXX} ${NACLPORTS_LDFLAGS} -shared  ${OBJECTS} -lppapi_cpp \
      -o libnacl_spawn.so
  fi

  ${CCCMD} -c ${START_DIR}/cli_main.c
  ${NACLAR} rcs libcli_main.a cli_main.o
  ${NACLRANLIB} libcli_main.a

  set +x
}

InstallStep() {
  Banner "Installing ${PACKAGE_NAME}"
  cp libnacl_spawn.a ${NACLPORTS_LIBDIR}
  if [[ "${NACL_GLIBC}" != "0" ]]; then
    cp libnacl_spawn.so ${NACLPORTS_LIBDIR}
  fi
  cp libcli_main.a ${NACLPORTS_LIBDIR}
}
