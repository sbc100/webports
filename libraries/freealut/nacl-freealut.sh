#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# nacl-freealut.sh
#
# usage:  nacl-freealut.sh
#
# this script downloads, patches, and builds freealut for Native Client.

source pkg_info
source ../../build_tools/common.sh

CFLAGS="${CFLAGS} -I${NACL_SDK_ROOT}/include"

export LIBS="-lm -lnosys"

DefaultPackageInstall
exit 0
