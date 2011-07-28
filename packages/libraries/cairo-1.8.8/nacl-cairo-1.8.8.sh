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

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/cairo-1.8.8.tar.gz
#readonly URL=http://cairographics.org/releases/cairo-1.8.8.tar.gz
readonly PATCH_FILE=cairo-1.8.8/nacl-cairo-1.8.8.patch
readonly PACKAGE_NAME=cairo-1.8.8

source ../../../build_tools/common.sh


DefaultPackageInstall
exit 0
