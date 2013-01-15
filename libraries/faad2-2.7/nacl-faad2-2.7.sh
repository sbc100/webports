#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-faad2-2.7.sh
#
# usage:  nacl-faad2-2.7.sh
#
# this script downloads, patches, and builds faad2 for Native Client 
#

source pkg_info
source ../../build_tools/common.sh

export LIBS=-lnosys

DefaultPackageInstall
exit 0
