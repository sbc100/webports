#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-install-linux-ports-1.sh
#
# usage:  nacl-install-linux-ports-1.sh
#
# This script builds the packages for Native Client that are designated to
# the bot named linux-ports-1
#

source ../bot_common.sh

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
cd ${SCRIPT_DIR}/../../..
make clean

# pango also builds glib, cairo, png, zlib, freetype, fontconfig, expat,
# and pixman
BuildPackage agg
BuildPackage openscenegraph
BuildPackage freeimage
BuildPackage imagemagick
BuildPackage pango

echo "@@@BUILD_STEP ${NACL_PACKAGES_BITSIZE}-bit Summary@@@"
if [[ $RESULT != 0 ]] ; then
  echo "@@@STEP_FAILURE@@@"
fi

echo -e "$MESSAGES"

exit $RESULT

