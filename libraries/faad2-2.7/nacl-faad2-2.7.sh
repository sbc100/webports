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

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/faad2-2.7.tar.gz
#readonly URL=http://sourceforge.net/projects/faac/files/faad2-src/faad2-2.7/faad2-2.7.tar.gz/download
readonly PATCH_FILE=faad2-2.7/nacl-faad2-2.7.patch
readonly PACKAGE_NAME=faad2-2.7

source ../../build_tools/common.sh

export LIBS=-lnosys

DefaultPackageInstall
exit 0
