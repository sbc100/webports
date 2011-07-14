#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-install-windows-ports-5.sh
#
# usage:  nacl-install-windows-ports-5.sh
#
# This script builds the packages for Native Client that are designated to
# the bot named windows-ports-5.
#

source ../bot_common.sh

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
cd ${SCRIPT_DIR}/../../../packages
make clean

BuildPackage fftw
BuildPackage jpeg
BuildPackage tiff
BuildPackage tinyxml
BuildPackage tommath
BuildPackage tomcrypt

echo "@@@BUILD_STEP ${NACL_PACKAGES_BITSIZE}-bit Summary@@@"
if [[ $RESULT != 0 ]] ; then
  echo "@@@STEP_FAILURE@@@"
fi

echo -e "$MESSAGES"

exit $RESULT
