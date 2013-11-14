#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-libxml2.sh
#
# usage:  nacl-libxml2.sh
#
# this script downloads, patches, and builds libxml2 for Native Client
#

source pkg_info
source ../../build_tools/common.sh

MAKE_TARGETS="libxml2.la"
INSTALL_TARGETS="install-libLTLIBRARIES install-data"
EXTRA_CONFIGURE_ARGS="--with-python=no"

DefaultPackageInstall
exit 0
