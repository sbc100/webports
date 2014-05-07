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
      --enable-targets=arm-none-eabi-nacl \
      --host=${NACL_CROSS_PREFIX} \
      --target=x86_64-nacl

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

  readonly TEMPLATE_EXPAND="${START_DIR}/../../build_tools/template_expand.py"
  readonly REVISION=$(cd ${START_DIR} && git number 2>/dev/null || svnversion)
  readonly REV_H=$(expr $REVISION / 65536)
  readonly REV_L=$(expr $REVISION % 65536)
  readonly VERSION=0.1.${REV_H}.${REV_L}

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
  MakeDir ${GDB_APP_DIR}/_platform_specific/${NACL_ARCH}
  LogExecute cp gdb/gdb.nexe \
      ${GDB_APP_DIR}/_platform_specific/${NACL_ARCH}/gdb${NACL_EXEEXT}

  pushd ${GDB_APP_DIR}
  python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      _platform_specific/*/gdb*${NACL_EXEEXT} \
      -s . \
      -o gdb.nmf
  LogExecute python ${TOOLS_DIR}/create_term.py gdb.nmf
  popd
  LogExecute cp ${START_DIR}/background.js ${GDB_APP_DIR}
  LogExecute cp ${START_DIR}/icon_16.png ${GDB_APP_DIR}
  LogExecute cp ${START_DIR}/icon_48.png ${GDB_APP_DIR}
  LogExecute cp ${START_DIR}/icon_128.png ${GDB_APP_DIR}
  # Generate a manifest.json (with key included).
  ${TEMPLATE_EXPAND} \
    ${START_DIR}/manifest.json.template \
    version=${VERSION} \
    key="$(cat ${START_DIR}/key.txt)" \
    >${GDB_APP_DIR}/manifest.json

  # Create uploadable version (key not included).
  local GDB_APP_UPLOAD_DIR="${PUBLISH_DIR}/gdb_app_upload"
  rm -rf ${GDB_APP_UPLOAD_DIR}
  LogExecute cp -r ${GDB_APP_DIR} ${GDB_APP_UPLOAD_DIR}
  ${TEMPLATE_EXPAND} \
    ${START_DIR}/manifest.json.template \
    version=${VERSION} \
    key="" \
    >${GDB_APP_UPLOAD_DIR}/manifest.json
  # Zip for upload to the web store.
  pushd ${PUBLISH_DIR}
  rm -f gdb_app_upload.zip
  zip -r gdb_app_upload.zip gdb_app_upload/
  popd

  # Debug Extension
  local DEBUG_EXT_DIR="${PUBLISH_DIR}/debug_extension"
  MakeDir ${DEBUG_EXT_DIR}
  InstallNaClTerm ${DEBUG_EXT_DIR}
  LogExecute cp ${START_DIR}/extension/background.js ${DEBUG_EXT_DIR}
  LogExecute cp ${START_DIR}/extension/devtools.html ${DEBUG_EXT_DIR}
  LogExecute cp ${START_DIR}/extension/devtools.js ${DEBUG_EXT_DIR}
  LogExecute cp ${START_DIR}/extension/icon_128.png ${DEBUG_EXT_DIR}
  LogExecute cp ${START_DIR}/extension/icon_16.png ${DEBUG_EXT_DIR}
  LogExecute cp ${START_DIR}/extension/icon_48.png ${DEBUG_EXT_DIR}
  LogExecute cp ${START_DIR}/extension/main.css ${DEBUG_EXT_DIR}
  LogExecute cp ${START_DIR}/extension/main.html ${DEBUG_EXT_DIR}
  LogExecute cp ${START_DIR}/extension/main.js ${DEBUG_EXT_DIR}
  ${TEMPLATE_EXPAND} \
    ${START_DIR}/extension/manifest.json.template \
    version=${VERSION} \
    >${DEBUG_EXT_DIR}/manifest.json
  # Zip for upload to the web store.
  pushd ${PUBLISH_DIR}
  rm -f debug_extension.zip
  zip -r debug_extension.zip debug_extension/
  popd
}

PostInstallTestStep() {
  if [[ ${OS_NAME} == Darwin && ${NACL_ARCH} == x86_64 ]]; then
    echo "Skipping gdb/debug tests on unsupported mac + x86_64 configuration."
  else
    LogExecute python ${START_DIR}/gdb_test.py -x -vv -a ${NACL_ARCH}
    LogExecute python ${START_DIR}/debugger_test.py -x -vv -a ${NACL_ARCH}
  fi
}
