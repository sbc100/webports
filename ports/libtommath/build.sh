#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh


BuildStep() {
  MAKE_TARGETS=mtest
  export EXEEXT=${NACL_EXEEXT}
  DefaultBuildStep
}


#TestStep() {
  # To run tests, pipe mtest.nexe output into test.nexe input
  #   mtest/mtest.exe | test.nexe
  # However, this test is setup to run forever, so we don't run
  # it as part of the build.
  #RunSelLdrCommand mtest/mtest.nexe | RunSelLdrCommand test.nexe
#}


InstallStep() {
  Banner "Installing"
  # copy libs and headers manually
  LogExecute cp *.h ${NACLPORTS_INCLUDE}
  LogExecute cp *.a ${NACLPORTS_LIBDIR}
}


PackageInstall
exit 0
