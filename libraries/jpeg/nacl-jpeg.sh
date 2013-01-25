#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-jpeg.sh
#
# usage:  nacl-jpeg.sh
#
# this script downloads, patches, and builds libjpeg for Native Client.

source pkg_info
source ../../build_tools/common.sh

INSTALL_TARGETS="install-lib install-headers"

DefaultPackageInstall
exit 0
