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

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/libvorbis-1.2.3.tar.gz
#readonly URL=http://downloads.xiph.org/releases/vorbis/libvorbis-1.2.3.tar.gz
readonly PATCH_FILE=nacl-libvorbis-1.2.3.patch
readonly PACKAGE_NAME=libvorbis-1.2.3

source ../../build_tools/common.sh

export LIBS="-lnosys -lm"

DefaultPackageInstall
exit 0
