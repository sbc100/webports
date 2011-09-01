#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-speex-1.2rc1.sh
#
# usage:  nacl-speex-1.2rc1.sh
#
# this script downloads, patches, and builds speex for Native Client 
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/speex-1.2rc1.tar.gz
#readonly URL=http://downloads.xiph.org/releases/speex/speex-1.2rc1.tar.gz
readonly PATCH_FILE=speex-1.2rc1/nacl-speex-1.2rc1.patch
readonly PACKAGE_NAME=speex-1.2rc1

source ../../build_tools/common.sh


DefaultPackageInstall
exit 0
