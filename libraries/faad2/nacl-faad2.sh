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

# TODO: Remove when this is fixed.
# https://code.google.com/p/nativeclient/issues/detail?id=3205
if [ "$NACL_ARCH" = "arm" ]; then
  export NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS//-O2/}"
fi

DefaultPackageInstall
exit 0
