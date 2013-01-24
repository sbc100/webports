#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-cairo-1.8.8.sh
#
# usage:  nacl-cairo-1.8.8.sh
#
# this script downloads, patches, and builds cairo for Native Client.
#

source pkg_info
source ../../build_tools/common.sh

# This is only necessary for pnacl
export ax_cv_c_float_words_bigendian=no

DefaultPackageInstall
exit 0
