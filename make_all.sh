#!/bin/sh
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# This script builds all naclports in all possible configurations.
# If you want to be sure your change won't break anythign this is
# a good place to start.

set -x
set -e

TARGETS="$*"
TARGETS=${TARGETS:-all}
BUILD_FLAGS=--ignore-disabled

export TOOLCHAIN
export NACL_ARCH
export BUILD_FLAGS

# x86_64 NaCl
NACL_ARCH=x86_64
TOOLCHAIN=glibc
make ${TARGETS}
TOOLCHAIN=newlib
make ${TARGETS}

# i686 NaCl
NACL_ARCH=i686
TOOLCHAIN=glibc
make ${TARGETS}
TOOLCHAIN=newlib
make ${TARGETS}

# ARM NaCl
NACL_ARCH=arm
TOOLCHAIN=newlib
make ${TARGETS}
BIONIC_TOOLCHAIN="${NACL_SDK_ROOT}/toolchain/*_arm_bionic"
if [ -n "$(shopt -s nullglob; echo ${BIONIC_TOOLCHAIN})" ]; then
  TOOLCHAIN=bionic
  make ${TARGETS}
fi

# PNaCl
NACL_ARCH=pnacl
TOOLCHAIN=pnacl
make ${TARGETS}
