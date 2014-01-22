#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


TestStep() {
  if [ ${NACL_ARCH} == "pnacl" ]; then
    local pexe=test/yajl_test
    local script=${BUILD_DIR}/yajl_test.sh
    TranslateAndWriteSelLdrScript ${pexe} x86-32 ${pexe}.x86-32.nexe ${script}
    (cd ../test && ./run_tests.sh ${script})
    TranslateAndWriteSelLdrScript ${pexe} x86-64 ${pexe}.x86-64.nexe ${script}
    (cd ../test && ./run_tests.sh ${script})
  else
    local script=${BUILD_DIR}/yajl_test.sh
    local nexe=test/yajl_test

    WriteSelLdrScript ${script} ${nexe}
    (cd ../test && LogExecute ./run_tests.sh ${script})
  fi
}


ConfigureStep() {
  EXTRA_CMAKE_ARGS="-DBUILD_SHARED=${NACL_GLIBC}"
  CMakeConfigureStep
}


BuildStep() {
  make all -j${OS_JOBS}
}
