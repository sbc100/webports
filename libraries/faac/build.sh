#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-faac-1.28.sh
#
# usage:  nacl-faac-1.28.sh
#
# this script downloads, patches, and builds faac for Native Client
#

source pkg_info
source ../../build_tools/common.sh

EXTRA_CONFIGURE_ARGS="--with-mp4v2=no"

DefaultPackageInstall
exit 0
