#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}
MAKE_TARGETS=mtest
export EXEEXT=${NACL_EXEEXT}

#TestStep() {
  # To run tests, pipe mtest.nexe output into test.nexe input
  #   mtest/mtest.exe | test.nexe
  # However, this test is setup to run forever, so we don't run
  # it as part of the build.
  #RunSelLdrCommand mtest/mtest.nexe | RunSelLdrCommand test.nexe
#}

InstallStep() {
  # copy libs and headers manually
  MakeDir ${DESTDIR_INCLUDE}
  MakeDir ${DESTDIR_LIB}
  LogExecute cp *.h ${DESTDIR_INCLUDE}/
  LogExecute cp *.a ${DESTDIR_LIB}/
}
