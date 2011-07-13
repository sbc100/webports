#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-lame-398-2.sh
#
# usage:  nacl-lame-398-2.sh
#
# this script downloads, patches, and builds lame for Native Client 
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/lame-398-2.tar.gz
#readonly URL=http://sourceforge.net/projects/lame/files/lame/3.98.2/lame-398-2.tar.gz/download
readonly PATCH_FILE=lame-398-2/nacl-lame-398-2.patch
readonly PACKAGE_NAME=lame-398-2

source ../../../build_tools/common.sh

export LIBS=-lnosys

DefaultPackageInstall
exit 0
