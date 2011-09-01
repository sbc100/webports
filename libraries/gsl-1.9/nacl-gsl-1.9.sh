#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-gsl-1.9.sh
#
# usage:  nacl-gsl-1.9.sh
#
# this script downloads, patches, and builds gsl for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/gsl-1.9.tar.gz
#readonly URL=http://ftp.thaios.net/gnu/gsl/gsl-1.9.tar.gz
readonly PATCH_FILE=gsl-1.9/nacl-gsl-1.9.patch
readonly PACKAGE_NAME=gsl-1.9
export LIBS="-lm"

source ../../build_tools/common.sh

DefaultPackageInstall
exit 0
