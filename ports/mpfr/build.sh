#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

if [ "${NACL_GLIBC}" = "1" ]; then
  NACLPORTS_CFLAGS+=" -fPIC"
fi
# Disable all assembly code by specifying none-none-none.
EXTRA_CONFIGURE_ARGS=--host=none-none-none

PackageInstall
exit 0
