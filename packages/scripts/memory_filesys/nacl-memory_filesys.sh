#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-memory_filesys.sh
#
# usage:  nacl-memory_filesys.sh
#
# this script downloads, patches, and builds memory_filesys for Native Client
#

readonly PACKAGE_NAME=memory_filesys

source ../../../build_tools/common.sh


CustomBuildStep() {
  Banner "Building ${PACKAGE_NAME}"
  export PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  MakeDir ${PACKAGE_DIR}
  ChangeDir ${PACKAGE_DIR}
  ${NACLCC} -c ${START_DIR}/nacl_mem_file.c -o nacl_mem_file.o
  ${NACLCC} -c ${START_DIR}/nacl_escape.c -o nacl_escape.o
  ${NACLCC} -c ${START_DIR}/nacl_simple_tar.c -o nacl_simple_tar.o
  ${NACLCC} -c ${START_DIR}/nacl_simple_io.c -o nacl_simple_io.o
  ${NACLAR} rcs libmemory_filesys.a \
      nacl_mem_file.o \
      nacl_escape.o \
      nacl_simple_tar.o \
      nacl_simple_io.o
  ${NACLRANLIB} libmemory_filesys.a
}

CustomInstallStep() {
  Banner "Installing ${PACKAGE_NAME}"
  export PACKAGE_DIR="${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}"
  cp ${PACKAGE_DIR}/libmemory_filesys.a ${NACL_SDK_USR_LIB}
  cp ${START_DIR}/termio.h ${NACL_SDK_USR_INCLUDE}
  mkdir -p ${NACL_SDK_USR_LIB}/memory_filesys
  cp ${START_DIR}/simple_tar.py ${NACL_SDK_USR_LIB}/memory_filesys/
  cp ${START_DIR}/*.js ${NACL_SDK_USR_LIB}/memory_filesys/
  DefaultTouchStep
}

CustomPackageInstall() {
  DefaultPreInstallStep
  CustomBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
