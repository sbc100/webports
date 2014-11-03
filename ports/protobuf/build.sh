# Copyright 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="src/protoc${NACL_EXEEXT}"

TestStep() {
  # Still a few issues with the non-lite unittests
  # TODO(sbc): add protobuf-test${NACL_EXEEXT} to this list
  TESTS="protobuf-lite-test${NACL_EXEEXT}"
  ChangeDir gtest
  LogExecute make -j${OS_JOBS}
  ChangeDir ../src
  LogExecute make -j${OS_JOBS} ${TESTS}
  for test in ${TESTS}; do
    RunSelLdrCommand ${test}
  done
}

ConfigureStep() {
  HOST_BUILD_DIR="${WORK_DIR}/build_host"
  EXTRA_CONFIGURE_ARGS="--with-protoc=$HOST_BUILD_DIR/src/protoc"
  if [ ! -f "${HOST_BUILD_DIR}/src/protoc" ]; then
    MakeDir "${HOST_BUILD_DIR}"
    ChangeDir "${HOST_BUILD_DIR}"
    LogExecute "${SRC_DIR}/configure"
    LogExecute make -C src -j${OS_JOBS} protoc
    ChangeDir ${BUILD_DIR}
  fi
  DefaultConfigureStep
}
