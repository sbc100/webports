#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-libogg-1.1.4.sh
#
# usage:  nacl-libogg-1.1.4.sh
#
# this script downloads, patches, and builds libogg for Native Client 
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/libogg-1.1.4.tar.gz
#readonly URL=http://downloads.xiph.org/releases/ogg/libogg-1.1.4.tar.gz
readonly PATCH_FILE=libogg-1.1.4/nacl-libogg-1.1.4.patch
readonly PACKAGE_NAME=libogg-1.1.4

source ../../../build_tools/common.sh


DefaultPackageInstall
exit 0
