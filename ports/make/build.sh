#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

CONFIG_SUB=config/config.sub

if [ "${NACL_GLIBC}" != "1" ]; then
  NACLPORTS_CFLAGS+=" -D_POSIX_VERSION"
fi

PackageInstall
exit 0
