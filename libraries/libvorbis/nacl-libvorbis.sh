#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-libvorbis-1.2.3.sh
#
# usage:  nacl-libvorbis-1.2.3.sh
#
# this script downloads, patches, and builds libvorbis for Native Client 
#

source pkg_info
source ../../build_tools/common.sh

export LIBS="-lnosys -lm"

DefaultPackageInstall
exit 0
