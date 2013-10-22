#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

RunSelLdrTests() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}/${NACL_BUILD_SUBDIR}
  pushd UnitTests/BulletUnitTests
  RunSelLdrCommand AppBulletUnitTests${NACL_EXEEXT}
  popd

  pushd Demos/HelloWorld
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

PackageInstall() {
  DefaultPackageInstall
  RunSelLdrTests
}

PackageInstall
exit 0
