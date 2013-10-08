#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

source pkg_info
source ../../build_tools/common.sh

RunSelLdrTests() {
  if [ $OS_SUBDIR = "windows" ]; then
    echo "Not running sel_ldr tests on Windows."
    return
  fi

  if [ $NACL_ARCH = "arm" ]; then
    echo "Not running sel_ldr tests on ARM."
    return
  fi

  if [ ${NACL_ARCH} == "pnacl" ]; then
    # Run once for each architecture.
    local pexe=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/${NACL_BUILD_SUBDIR}/test/testil
    local script=${pexe}.sh

    TranslateAndWriteSelLdrScript ${pexe} x86-32 ${pexe}.x86-32.nexe ${script}
    cd ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/${NACL_BUILD_SUBDIR}/test && make check

    TranslateAndWriteSelLdrScript ${pexe} x86-64 ${pexe}.x86-64.nexe ${script}
    cd ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/${NACL_BUILD_SUBDIR}/test && make check
  else
    local nexe=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/${NACL_BUILD_SUBDIR}/test/testil
    local script=${nexe}.sh

    WriteSelLdrScript ${script} ${nexe}

    cd ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/${NACL_BUILD_SUBDIR}/test && make check
  fi
}


DefaultPackageInstall
#RunSelLdrTests
exit 0
