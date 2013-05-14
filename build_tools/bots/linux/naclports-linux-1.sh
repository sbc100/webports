#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# This script builds the packages for Native Client that are designated to
# the bot named linux-<libc>-1.

source ../bot_common.sh

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
cd ${SCRIPT_DIR}/../../..
make clean

# pango also builds glib
# cairo also builds png, zlib, freetype, fontconfig, expat, and pixman
BuildPackage agg
BuildPackage openscenegraph
BuildPackage freeimage
BuildPackage imagemagick
BuildPackage cairo
BuildPackage pango
BuildPackage openal
BuildPackage ncurses
BuildPackage box2d
BuildPackage xml2
BuildPackage yajl
BuildPackage mng
BuildPackage lcms
BuildPackage DevIL
BuildPackage physfs
BuildPackage mpg123

echo "@@@BUILD_STEP ${NACL_ARCH} Summary@@@"
if [[ $RESULT != 0 ]] ; then
  echo "@@@STEP_FAILURE@@@"
  echo -e "$MESSAGES"
fi

exit $RESULT
