#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

export LIBS="-lnosys -lm"

# TODO: Remove when this is fixed.
# https://code.google.com/p/nativeclient/issues/detail?id=3599
if [ "$NACL_ARCH" = "pnacl" ]; then
  export NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS//-O2/}"
fi

CONFIG_SUB=config/config.sub
DefaultPackageInstall
exit 0

