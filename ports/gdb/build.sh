#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

ConfigureStep() {
  SetupCrossEnvironment

  cp ${START_DIR}/gdb_pepper.c ${SRC_DIR}/gdb
  LogExecute ${SRC_DIR}/configure --with-curses --with-expat \
      --with-system-readline \
      --disable-libmcheck \
      --prefix=${PREFIX} \
      --host=${NACL_CROSS_PREFIX}

  # If the .info files don't exist, "make all" will try to recreate it with the
  # "makeinfo" tool, which isn't normally installed.
  # Just copy the ones from the repo to the build directory.
  MakeDir ${BUILD_DIR}/{gdb,bfd}/doc
  ChangeDir ${SRC_DIR}
  find gdb bfd -name '*.info' -exec cp {} ${BUILD_DIR}/{} \;
}

BuildStep() {
  # gdb configures its submodules at build time so we need to setup
  # the cross enrionment here.  Without this CPPFLAGS doesn't get set
  # in gdb/Makefile.
  SetupCrossEnvironment
  DefaultBuildStep

  # Build test module.
  LogExecute ${CXX} ${CPPFLAGS} ${CXXFLAGS} ${LDFLAGS} -g \
      ${START_DIR}/test_module.cc \
      -o ${BUILD_DIR}/test_module_${NACL_ARCH}.nexe -lppapi_cpp -lppapi
}

InstallStep() {
  DefaultInstallStep

  MakeDir ${PUBLISH_DIR}

  # Tests
  local TEST_OUT_DIR="${PUBLISH_DIR}/tests"
  MakeDir ${TEST_OUT_DIR}
  LogExecute cp ${BUILD_DIR}/test_module_*.nexe ${TEST_OUT_DIR}
  pushd ${TEST_OUT_DIR}
  python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      test_module_*${NACL_EXEEXT} \
      -s . \
      -o test_module.nmf
  popd

  # GDB App
  local GDB_APP_DIR="${PUBLISH_DIR}/gdb_app"
  MakeDir ${GDB_APP_DIR}
  LogExecute cp gdb/gdb.nexe \
      ${GDB_APP_DIR}/gdb_${NACL_ARCH}${NACL_EXEEXT}

  pushd ${GDB_APP_DIR}
  python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      gdb_*${NACL_EXEEXT} \
      -s . \
      -o gdb.nmf
  LogExecute python ${TOOLS_DIR}/create_term.py gdb.nmf
  popd
  LogExecute cp ${START_DIR}/background.js ${GDB_APP_DIR}
  LogExecute cp ${START_DIR}/manifest.json ${GDB_APP_DIR}
  LogExecute cp ${START_DIR}/icon_16.png ${GDB_APP_DIR}
  LogExecute cp ${START_DIR}/icon_48.png ${GDB_APP_DIR}
  LogExecute cp ${START_DIR}/icon_128.png ${GDB_APP_DIR}

  # Debug Extension
  local DEBUG_EXT_DIR="${PUBLISH_DIR}/debug_extension"
  MakeDir ${DEBUG_EXT_DIR}
  InstallNaClTerm ${DEBUG_EXT_DIR}
  LogExecute cp ${START_DIR}/extension/* ${DEBUG_EXT_DIR}
}

PostInstallTestStep() {
  if [[ ${OS_NAME} == Darwin && ${NACL_ARCH} == x86_64 ]]; then
    echo "Skipping gdb/debug tests on unsupported mac + x86_64 configuration."
  else
    LogExecute python ${START_DIR}/gdb_test.py -x -vv -a ${NACL_ARCH}
    LogExecute python ${START_DIR}/debugger_test.py -x -vv -a ${NACL_ARCH}
  fi
}
