#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-install-linux-ports-0.sh
#
# usage:  nacl-install-linux-ports-0.sh
#
# This script builds the packages for Native Client that are designated to
# the bot named linux-ports-0.
#

source ../bot_common.sh

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
cd ${SCRIPT_DIR}/../../..
make clean

# ffmpeg also builds lame, vorbis, theora, and ogg
# sdl_* build sdl, png, freetype
BuildPackage ffmpeg
BuildPackage speex
BuildPackage flac
BuildPackage gsl
BuildPackage sdl_image
BuildPackage sdl_ttf
BuildPackage sdl_net
BuildPackage sdl_mixer
BuildPackage scummvm
BuildPackage bochs

echo "@@@BUILD_STEP ${NACL_PACKAGES_BITSIZE}-bit Summary@@@"
if [[ $RESULT != 0 ]] ; then
  echo "@@@STEP_FAILURE@@@"
fi

echo -e "$MESSAGES"

exit $RESULT
