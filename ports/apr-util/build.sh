#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

EXTRA_CONFIGURE_ARGS="--with-apr=${NACLPORTS_PREFIX}"
EXTRA_CONFIGURE_ARGS+=" --with-expat=${NACLPORTS_PREFIX}"

PackageInstall
exit 0
