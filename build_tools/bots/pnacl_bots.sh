#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

######################################################################
# Notes on directory layout:
# makefile location (base_dir):  naclports/src
# bot script location:           naclports/src/build_tools/bots/
# toolchain injection point:     specified externally via NACL_SDK_ROOT.
######################################################################

source bot_common.sh

set -o nounset
set -o errexit

readonly BASE_DIR="$(dirname $0)/../.."
cd ${BASE_DIR}

make clean

BuildPackage all

echo "@@@BUILD_STEP ${NACL_ARCH} Summary@@@"
if [[ $RESULT != 0 ]] ; then
  echo "@@@STEP_FAILURE@@@"
  echo -e "$MESSAGES"
fi

exit $RESULT
