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
export BUILD_FLAGS=--ignore-disabled

# x86_64 NaCl
export NACL_ARCH=x86_64
export NACL_GLIBC=1
make ${TARGETS}
unset NACL_GLIBC
make ${TARGETS}

# i686 NaCl
export NACL_ARCH=i686
export NACL_GLIBC=1
make ${TARGETS}
unset NACL_GLIBC
make ${TARGETS}

# ARM NaCl
export NACL_ARCH=arm
make ${TARGETS}

# PNaCl
export NACL_ARCH=pnacl
make ${TARGETS}
