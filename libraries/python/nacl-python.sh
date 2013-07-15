#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

EXECUTABLES=python.nexe
# Currently this package only builds on linux.
# The build relies on certain host binaries and pythong's configure
# requires us to sett --build= as well as --host=.
EXTRA_CONFIGURE_ARGS="--disable-ipv6 --with-suffix=.nexe --build=x86_64-linux-gnu"
export MAKEFLAGS="PGEN=../build-nacl-host/Parser/pgen"
HERE=$(cd "$(dirname "$BASH_SOURCE")" ; pwd)

BuildHostPython() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  MakeDir build-nacl-host
  ChangeDir build-nacl-host
  LogExecute ../configure
  LogExecute make -j${OS_JOBS} python Parser/pgen
}

CustomConfigureStep() {
  BuildHostPython
  export CROSS_COMPILE=true
  # We pre-seed configure with certain results that it cannot determine
  # since we are doing a cross compile.  The $CONFIG_SITE file is sourced
  # by configure early on.
  export CONFIG_SITE=${HERE}/config.site
  DefaultConfigureStep
}

CustomTestStep() {
  WriteSelLdrScript python python.nexe
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  DefaultTranslateStep
  DefaultValidateStep
  CustomTestStep
  DefaultInstallStep
}

CustomPackageInstall
exit 0
