#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

PACKAGE_NAME=python_ppapi
source ../../../build_tools/common.sh

CustomBuildStep() {
  # The sample is built using the NaCl SDK common.mk system.
  # We override $(OUTBASE) to force the build system to put
  # all its artifacts in ${NACL_PACKAGES_REPOSITORY} rather
  # than alongside the Makefile.
  export OUTBASE=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  export NACLPORTS_INCLUDE
  export NACL_PACKAGES_PUBLISH

  MakeDir ${OUTBASE}
  if [ "${NACL_GLIBC}" = "1" ]; then
    MAKEFLAGS+=" TOOLCHAIN=glibc"
  else
    MAKEFLAGS+=" TOOLCHAIN=newlib"
  fi
  MAKEFLAGS+=" NACL_ARCH=${NACL_ARCH_ALT}"
  export MAKEFLAGS
  ChangeDir ${START_DIR}
  DefaultBuildStep
}

CustomPackageInstall() {
  DefaultPreInstallStep
  CustomBuildStep
  DefaultInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
