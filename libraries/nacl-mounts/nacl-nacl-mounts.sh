#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
#
# nacl-mounts.sh
#
# usage:  ./nacl-mounts.sh
#
# this script builds nacl-mounts
#

readonly PACKAGE_NAME=nacl-mounts

source ../../build_tools/common.sh

RunTests() {
 make clean && make all && ./tests_out/nacl_mounts_tests
 make clean
}

CustomBuildStep() {
  Banner "Building ${PACKAGE_NAME}"
  export PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  MakeDir ${PACKAGE_DIR}
  ChangeDir ${PACKAGE_DIR}
  set -x
  export CXXCMD="${NACLCC} -I${START_DIR}"
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
  ${CXXCMD} -c ${START_DIR}/util/SimpleAutoLock.cc
  ${CXXCMD} -c ${START_DIR}/util/nacl_simple_tar.c
  ${CXXCMD} -c ${START_DIR}/console/terminal.c
  ${CXXCMD} -c ${START_DIR}/console/terminal_stubs.c
  ${CXXCMD} -c ${START_DIR}/memory/MemMount.cc
  ${CXXCMD} -c ${START_DIR}/memory/MemNode.cc
  ${CXXCMD} -c ${START_DIR}/AppEngine/AppEngineMount.cc
  ${CXXCMD} -c ${START_DIR}/AppEngine/AppEngineNode.cc
  ${CXXCMD} -c ${START_DIR}/http/HTTPMount.cc
  ${CXXCMD} -c ${START_DIR}/http/HTTPNode.cc
  ${CXXCMD} -c ${START_DIR}/pepper/PepperMount.cc
  ${CXXCMD} -c ${START_DIR}/pepper/PepperFileIOJob.cc
  ${CXXCMD} -c ${START_DIR}/console/ConsoleMount.cc
  ${CXXCMD} -c ${START_DIR}/console/JSPipeMount.cc
  ${CXXCMD} -c ${START_DIR}/console/JSPostMessageBridge.cc
  ${NACLAR} rcs libnacl-mounts.a \
      MountManager.o \
      KernelProxy.o \
      Entry.o \
      MainThreadRunner.o \
      UrlLoaderJob.o \
      Path.o \
      SimpleAutoLock.o \
      nacl_simple_tar.o \
      terminal.o \
      terminal_stubs.o \
      MemMount.o \
      MemNode.o \
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
      JSPostMessageBridge.o

  ${NACLRANLIB} libnacl-mounts.a
  set +x
}

CustomInstallStep() {
  Banner "Installing ${PACKAGE_NAME}"
  export PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  cp ${PACKAGE_DIR}/libnacl-mounts.a ${NACL_SDK_USR_LIB}
  mkdir -p ${NACL_SDK_USR_LIB}/nacl-mounts/util
  cp ${START_DIR}/console/console.js ${NACL_SDK_USR_LIB}/nacl-mounts
  cp ${START_DIR}/console/termio.h ${NACL_SDK_USR_INCLUDE}

  mkdir -p ${NACL_SDK_USR_INCLUDE}/nacl-mounts
  for DIR in console base util memory http2 AppEngine pepper; do
    mkdir -p ${NACL_SDK_USR_INCLUDE}/nacl-mounts/${DIR}
    cp ${START_DIR}/${DIR}/*.h ${NACL_SDK_USR_INCLUDE}/nacl-mounts/${DIR}
  done
}

CustomPackageInstall() {
  RunTests
  DefaultPreInstallStep
  CustomBuildStep
  CustomInstallStep
  DefaultCleanUpStep
  DefaultTouchStep
}

CustomPackageInstall
exit 0
