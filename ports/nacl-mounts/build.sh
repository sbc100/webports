#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh


RunTests() {
  LogExecute make clean
  LogExecute make all
  LogExecute ./tests_out/nacl_mounts_tests
}


TestStep() {
  Banner "Testing ${PACKAGE_NAME}"

  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export CFLAGS=${NACLPORTS_CFLAGS}
  export CXXFLAGS=${NACLPORTS_CXXFLAGS}
  export LDFLAGS="${NACLPORTS_LDFLAGS} -L\"$PWD\""
  export PATH=${NACL_BIN_PATH}:${PATH};

  # Add PWD to SEL_LDR_LIB_PATH so that the local build
  # of the library can be found when the test runs without
  # needing to install the into the toolchain.
  export SEL_LDR_LIB_PATH="$PWD"

  MakeDir test.nacl
  ChangeDir test.nacl
  LogExecute make -f ${START_DIR}/test.nacl/Makefile

  RunSelLdrCommand nacl_mounts_sel_ldr_tests
  ChangeDir ..
}


BuildStep() {
  Banner "Building ${PACKAGE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  MakeDir ${NACL_BUILD_SUBDIR}
  ChangeDir ${NACL_BUILD_SUBDIR}
  if [ "${NACL_GLIBC}" = "1" ]; then
    NACLPORTS_CFLAGS+=" -fPIC"
  fi
  local OBJECTS="\
      MountManager.o \
      KernelProxy.o \
      Entry.o \
      newlib_compat.o \
      MainThreadRunner.o \
      UrlLoaderJob.o \
      Path.o \
      nacl_simple_tar.o \
      terminal.o \
      terminal_stubs.o \
      MemMount.o \
      MemNode.o \
      RandomDevice.o \
      NullDevice.o \
      DevMount.o \
      AppEngineMount.o \
      AppEngineNode.o \
      HTTPMount.o \
      HTTPNode.o \
      HTTP2Mount.o \
      HTTP2FSOpenJob.o \
      HTTP2OpenJob.o \
      HTTP2ReadJob.o \
      PepperMount.o \
      PepperFileIOJob.o \
      ConsoleMount.o \
      JSPipeMount.o \
      JSPostMessageBridge.o \
      TcpSocket.o \
      TcpServerSocket.o \
      SocketSubSystem.o \
      BufferMount.o"
  set -x
  NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS} -I${START_DIR}/.. -I${START_DIR}"
  CXXCMD="${NACLCXX} ${NACLPORTS_CFLAGS}"
  CCCMD="${NACLCC} ${NACLPORTS_CFLAGS}"
  ${CXXCMD} -c ${START_DIR}/net/TcpSocket.cc
  ${CXXCMD} -c ${START_DIR}/net/TcpServerSocket.cc
  ${CXXCMD} -c ${START_DIR}/net/SocketSubSystem.cc
  ${CXXCMD} -c ${START_DIR}/net/newlib_compat.cc
  ${CXXCMD} -c ${START_DIR}/buffer/BufferMount.cc
  ${CXXCMD} -c ${START_DIR}/http2/HTTP2Mount.cc
  ${CXXCMD} -c ${START_DIR}/http2/HTTP2FSOpenJob.cc
  ${CXXCMD} -c ${START_DIR}/http2/HTTP2OpenJob.cc
  ${CXXCMD} -c ${START_DIR}/http2/HTTP2ReadJob.cc
  ${CXXCMD} -c ${START_DIR}/base/MountManager.cc
  ${CXXCMD} -c ${START_DIR}/base/KernelProxy.cc
  ${CXXCMD} -c ${START_DIR}/base/Entry.cc
  ${CXXCMD} -c ${START_DIR}/base/MainThreadRunner.cc
  ${CXXCMD} -c ${START_DIR}/base/UrlLoaderJob.cc
  ${CXXCMD} -c ${START_DIR}/util/Path.cc
  ${CXXCMD} -c ${START_DIR}/memory/MemMount.cc
  ${CXXCMD} -c ${START_DIR}/memory/MemNode.cc
  ${CXXCMD} -c ${START_DIR}/dev/DevMount.cc
  ${CXXCMD} -c ${START_DIR}/dev/NullDevice.cc
  ${CXXCMD} -c ${START_DIR}/dev/RandomDevice.cc
  ${CXXCMD} -c ${START_DIR}/AppEngine/AppEngineMount.cc
  ${CXXCMD} -c ${START_DIR}/AppEngine/AppEngineNode.cc
  ${CXXCMD} -c ${START_DIR}/http/HTTPMount.cc
  ${CXXCMD} -c ${START_DIR}/http/HTTPNode.cc
  ${CXXCMD} -c ${START_DIR}/pepper/PepperMount.cc
  ${CXXCMD} -c ${START_DIR}/pepper/PepperFileIOJob.cc
  ${CXXCMD} -c ${START_DIR}/console/ConsoleMount.cc
  ${CXXCMD} -c ${START_DIR}/console/JSPipeMount.cc
  ${CXXCMD} -c ${START_DIR}/console/JSPostMessageBridge.cc
  ${CCCMD} -c ${START_DIR}/util/nacl_simple_tar.c
  ${CCCMD} -c ${START_DIR}/console/terminal.c
  ${CCCMD} -c ${START_DIR}/console/terminal_stubs.c

  ${NACLAR} rcs libnacl-mounts.a ${OBJECTS}
  ${NACLRANLIB} libnacl-mounts.a

  if [ "${NACL_GLIBC}" = "1" ]; then
    ${NACLCXX} ${NACLPORTS_LDFLAGS} -shared -lppapi_cpp -o libnacl-mounts.so ${OBJECTS}
  fi

  set +x
}


InstallStep() {
  Banner "Installing ${PACKAGE_NAME}"
  cp libnacl-mounts.a ${NACLPORTS_LIBDIR}
  mkdir -p ${NACLPORTS_LIBDIR}/nacl-mounts/util
  cp ${START_DIR}/console/console.js ${NACLPORTS_LIBDIR}/nacl-mounts
  cp ${START_DIR}/http2/genfs.py ${NACLPORTS_LIBDIR}/nacl-mounts/util

  # GLibC toolchain has termio.h so don't copy stub header.
  if [[ "${NACL_GLIBC}" = "0" ]]; then
    cp ${START_DIR}/console/termio.h ${NACLPORTS_INCLUDE}
  else
    cp libnacl-mounts.so ${NACLPORTS_LIBDIR}
  fi

  mkdir -p ${NACLPORTS_INCLUDE}/nacl-mounts
  for DIR in console base util memory net http2 AppEngine pepper buffer; do
    mkdir -p ${NACLPORTS_INCLUDE}/nacl-mounts/${DIR}
    cp ${START_DIR}/${DIR}/*.h ${NACLPORTS_INCLUDE}/nacl-mounts/${DIR}
  done
}


ExtractStep() {
  MakeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
}


PackageInstall
exit 0
