#!/bin/bash
# Copyright (c) 2009 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that be
# found in the LICENSE file.
#

# nacl-install-all-bitsize.sh
#
# usage:  nacl-install-all-bitsize.sh [32|64]
#
# This script builds all packages listed below for Native Client
# using the specified bitsize (either "32" or "64").
# Packages with no dependencies should be listed first.
#

set -o nounset
set -o errexit


RESULT=0
MESSAGES=


# need to define NACL_PACKAGES_BITSIZE before pulling in common.sh
bitsize=${1:-"32"}
if [ "${bitsize}" = "32" ] ; then
  export NACL_PACKAGES_BITSIZE="32"
elif [ "${bitsize}" = "64" ] ; then
  export NACL_PACKAGES_BITSIZE="64"
else
  echo "The bitsize to build must be '32' or '64', you listed: ${bitsize}." 1>&2
  exit 1
fi


RunInstallScript() {
  local CURRENT_DIR=`pwd -P`
  cd scripts/$1
  if ./$2 ; then
    echo "naclports nacl-install-all: Install SUCCEEDED $1 \
($NACL_PACKAGES_BITSIZE)"
  else
    MESSAGE="naclports nacl-install-all: Install FAILED for $1 \
($NACL_PACKAGES_BITSIZE)"
    echo $MESSAGE
    MESSAGES="$MESSAGES\n$MESSAGE"
    RESULT=1
  fi
  cd $CURRENT_DIR
}


RunInstallScript fftw-3.2.2 nacl-fftw-3.2.2.sh
RunInstallScript libtommath-0.41 nacl-libtommath-0.41.sh
RunInstallScript libtomcrypt-1.17 nacl-libtomcrypt-1.17.sh
RunInstallScript zlib-1.2.3 nacl-zlib-1.2.3.sh
RunInstallScript jpeg-6b nacl-jpeg-6b.sh
RunInstallScript libpng-1.2.40 nacl-libpng-1.2.40.sh
RunInstallScript tiff-3.9.1 nacl-tiff-3.9.1.sh
RunInstallScript FreeImage-3.14.1 nacl-FreeImage-3.14.1.sh
RunInstallScript libogg-1.1.4 nacl-libogg-1.1.4.sh
RunInstallScript libvorbis-1.2.3 nacl-libvorbis-1.2.3.sh
RunInstallScript lame-398-2 nacl-lame-398-2.sh
RunInstallScript faad2-2.7 nacl-faad2-2.7.sh
RunInstallScript faac-1.28 nacl-faac-1.28.sh
RunInstallScript libtheora-1.1.1 nacl-libtheora-1.1.1.sh
RunInstallScript flac-1.2.1 nacl-flac-1.2.1.sh
RunInstallScript speex-1.2rc1 nacl-speex-1.2rc1.sh
RunInstallScript x264-snapshot-20091023-2245 nacl-x264-snapshot-20091023-2245.sh
RunInstallScript lua-5.1.4 nacl-lua-5.1.4.sh
RunInstallScript tinyxml nacl-tinyxml.sh
RunInstallScript expat-2.0.1 nacl-expat-2.0.1.sh
RunInstallScript pixman-0.16.2 nacl-pixman-0.16.2.sh
RunInstallScript gsl-1.9 nacl-gsl-1.9.sh
RunInstallScript freetype-2.1.10 nacl-freetype-2.1.10.sh
RunInstallScript fontconfig-2.7.3 nacl-fontconfig-2.7.3.sh
RunInstallScript agg-2.5 nacl-agg-2.5.sh
RunInstallScript cairo-1.8.8 nacl-cairo-1.8.8.sh
RunInstallScript ImageMagick-6.5.4-10 nacl-ImageMagick-6.5.4-10.sh
RunInstallScript ffmpeg-0.5 nacl-ffmpeg-0.5.sh
RunInstallScript Mesa-7.6 nacl-Mesa-7.6.sh
RunInstallScript libmodplug-0.8.7 nacl-libmodplug-0.8.7.sh
RunInstallScript memory_filesys nacl-memory_filesys.sh
RunInstallScript nethack-3.4.3 nacl-nethack-3.4.3.sh
RunInstallScript OpenSceneGraph-2.9.7 nacl-OpenSceneGraph-2.9.7.sh

echo -e "$MESSAGES"

exit $RESULT
