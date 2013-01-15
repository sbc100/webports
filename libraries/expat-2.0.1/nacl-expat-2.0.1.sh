#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-expat-2.0.1.sh
#
# usage:  nacl-expat-2.0.1.sh
#
# this script downloads, patches, and builds expat for Native Client
#

source pkg_info
source ../../build_tools/common.sh

export LIBS=-lnosys

DefaultPackageInstall
exit 0
