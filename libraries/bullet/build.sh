#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

TestStep() {
  Banner "Testing ${PACKAGE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}/${NACL_BUILD_SUBDIR}

  if [ "${NACL_GLIBC}" = "1" ]; then
    local exe_dir=.libs
  else
    local exe_dir=
  fi

  pushd UnitTests/BulletUnitTests/${exe_dir}
  RunSelLdrCommand AppBulletUnitTests${NACL_EXEEXT}
  popd

  pushd Demos/HelloWorld/${exe_dir}
  RunSelLdrCommand AppHelloWorld${NACL_EXEEXT}
  popd
}


AutogenStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  # Remove \r\n from the shell script.
  sed -i.bak "s/\r$//" ./autogen.sh
  /bin/sh ./autogen.sh
  PatchConfigure
  PatchConfigSub
}


ConfigureStep() {
  AutogenStep
  DefaultConfigureStep
}

PackageInstall
exit 0
