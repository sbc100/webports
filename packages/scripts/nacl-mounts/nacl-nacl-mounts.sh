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

source ../../../build_tools/common.sh

RunTests() {
 make clean && make all && ./tests_out/nacl_mounts_tests
 make clean
}

CustomBuildStep() {
  Banner "Building ${PACKAGE_NAME}"
  export PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  MakeDir ${PACKAGE_DIR}
  ChangeDir ${PACKAGE_DIR}
  ${NACLCC} -c ${START_DIR}/base/MountManager.cc -o MountManager.o
  ${NACLCC} -c ${START_DIR}/base/KernelProxy.cc -o KernelProxy.o
  ${NACLCC} -c ${START_DIR}/base/Entry.cc -o Entry.o
  ${NACLCC} -c ${START_DIR}/base/MainThreadRunner.cc -o MainThreadRunner.o
  ${NACLCC} -c ${START_DIR}/base/UrlLoaderJob.cc -o UrlLoaderJob.o
  ${NACLCC} -c ${START_DIR}/util/Path.cc -o Path.o
  ${NACLCC} -c ${START_DIR}/util/SimpleAutoLock.cc -o SimpleAutoLock.o
  ${NACLCC} -c ${START_DIR}/memory/MemMount.cc -o MemMount.o
  ${NACLCC} -c ${START_DIR}/memory/MemNode.cc -o MemNode.o
  ${NACLCC} -c ${START_DIR}/AppEngine/AppEngineMount.cc -o AppEngineMount.o
  ${NACLCC} -c ${START_DIR}/AppEngine/AppEngineNode.cc -o AppEngineNode.o
  ${NACLCC} -c ${START_DIR}/console/ConsoleMount.cc -o ConsoleMount.o
  ${NACLAR} rcs libnacl-mounts.a \
      MountManager.o \
      KernelProxy.o \
      Entry.o \
      MainThreadRunner.o \
      UrlLoaderJob.o \
      Path.o \
      SimpleAutoLock.o \
      MemMount.o \
      MemNode.o \
      AppEngineMount.o \
      AppEngineNode.o \
      ConsoleMount.o

  ${NACLRANLIB} libnacl-mounts.a
}

CustomInstallStep() {
  Banner "Installing ${PACKAGE_NAME}"
  export PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  cp ${PACKAGE_DIR}/libnacl-mounts.a ${NACL_SDK_USR_LIB}
}

CustomPackageInstall() {
  RunTests
  DefaultPreInstallStep
  CustomBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
