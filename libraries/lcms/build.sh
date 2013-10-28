#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

source pkg_info
source ../../build_tools/common.sh

export LDFLAGS=-lnosys

DefaultPackageInstall
exit 0
