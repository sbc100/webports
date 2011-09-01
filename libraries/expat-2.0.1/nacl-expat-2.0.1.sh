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

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/expat-2.0.1.tar.gz
#readonly URL=http://sourceforge.net/projects/expat/files/expat/2.0.1/expat-2.0.1.tar.gz/download
readonly PATCH_FILE=nacl-expat-2.0.1.patch
readonly PACKAGE_NAME=expat-2.0.1

source ../../build_tools/common.sh

export LIBS=-lnosys

DefaultPackageInstall
exit 0
