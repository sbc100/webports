#!/bin/bash
# Copyright (c) 2009 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that be
# found in the LICENSE file.
#

# nacl-protobuf-2.3.0.sh
#
# usage:  nacl-protobuf-2.3.0.sh
#
# this script downloads, patches, and builds tinyxml for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/protobuf-2.3.0.tar.gz
#readonly URL=http://protobuf.googlecode.com/files/protobuf-2.3.0.tar.gz
readonly PATCH_FILE=protobuf-2.3.0/nacl-protobuf-2.3.0.patch
readonly PACKAGE_NAME=protobuf-2.3.0

source ../common.sh

DefaultPackageInstall
exit 0
