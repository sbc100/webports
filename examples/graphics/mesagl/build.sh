#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../../build_tools/common.sh

BuildStep() {
  # The sample is built using the NaCl SDK common.mk system.
  # We override $(OUTBASE) to force the build system to put
  # all its artifacts in ${NACL_PACKAGES_REPOSITORY} rather
  # than alongside the Makefile.
  export OUTBASE=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  export NACLPORTS_INCLUDE
  export NACL_PACKAGES_PUBLISH
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    MAKEFLAGS+=" TOOLCHAIN=pnacl"
  elif [ "${NACL_GLIBC}" = "1" ]; then
    MAKEFLAGS+=" TOOLCHAIN=glibc"
    MAKEFLAGS+=" NACL_ARCH=${NACL_ARCH_ALT}"
  else
    MAKEFLAGS+=" TOOLCHAIN=newlib"
    MAKEFLAGS+=" NACL_ARCH=${NACL_ARCH_ALT}"
  fi
  export MAKEFLAGS
  ChangeDir ${START_DIR}
  DefaultBuildStep
}

PackageInstall
exit 0
