#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-install-mac-ports-2.sh
#
# usage:  nacl-install-mac-ports-2.sh
#
# This script builds the packages for Native Client that are designated to
# the bot named mac-ports-2
#

source ../bot_common.sh

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
cd ${SCRIPT_DIR}/../../../packages
make clean

# nethack also builds memory_filesys
BuildPackage nethack
BuildPackage faac
BuildPackage lua
BuildPackage modplug
BuildPackage fftw
BuildPackage tommath
BuildPackage tomcrypt
BuildPackage jpeg
BuildPackage tiff
BuildPackage faad
BuildPackage tinyxml
BuildPackage mesa
BuildPackage cfitsio
BuildPackage boost
BuildPackage protobuf

echo "@@@BUILD_STEP ${NACL_PACKAGES_BITSIZE}-bit Summary@@@"
if [[ $RESULT != 0 ]] ; then
  echo "@@@STEP_FAILURE@@@"
fi

echo -e "$MESSAGES"

exit $RESULT
