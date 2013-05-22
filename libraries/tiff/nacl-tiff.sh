#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-tiff.sh
#
# usage:  nacl-tiff.sh
#
# this script downloads, patches, and builds tiff for Native Client

source pkg_info
source ../../build_tools/common.sh

export LIBS="-lnosys -lm"

CONFIG_SUB=config/config.sub
DefaultPackageInstall
exit 0

