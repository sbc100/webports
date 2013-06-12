#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# The nacl-install-{linux,mac,windows}-*.sh scripts should source this script.

set -o nounset
set -o errexit

RESULT=0
MESSAGES=

CalculatePackageShards()
{
  local ALL_PACKAGES=$(make -s package_list)

  PKG_LIST_PART_0="
    libraries/glibc-compat
    libraries/gsl
    libraries/faac
    libraries/openssl
    libraries/jsoncpp
    libraries/lua
    libraries/fftw
    libraries/libtommath
    libraries/libtomcrypt
    libraries/x264
    libraries/protobuf
    libraries/gc
    libraries/cfitsio
    libraries/libmodplug
    libraries/faad2
    libraries/Mesa
    libraries/box2d
    libraries/gtest
    libraries/nacl-mounts
    libraries/ncurses
    examples/games/nethack
  "

  PKG_LIST_PART_1="
    libraries/libmikmod
    libraries/gtest
    libraries/zlib
    libraries/libpng
    libraries/libmng
    libraries/freetype
    libraries/nacl-mounts
    libraries/Regal
    libraries/SDL
    libraries/SDL_image
    libraries/SDL_ttf
    libraries/SDL_net
    libraries/SDL_mixer
    libraries/libogg
    libraries/libvorbis
    libraries/speex
    libraries/flac
    libraries/lame
    libraries/libtheora
    libraries/ffmpeg
    libraries/jpeg
    libraries/tiff
    libraries/lcms
    libraries/DevIL
    examples/games/scummvm
    examples/games/snes9x
    examples/systems/dosbox
    examples/systems/bochs
  "

  for PKG in ${PKG_LIST_PART_0} ${PKG_LIST_PART_1}; do
    if [[ ! "${ALL_PACKAGES}" =~ "${PKG}" ]]; then
      echo "Invalid package name: ${PKG}"
      echo "@@@STEP_FAILURE@@@"
      exit 1
    fi
  done

  local DEPS=$(make -s PRINT_DEPS=1 ${PKG_LIST_PART_0})
  for DEP in ${DEPS}; do
    if [[ ! "${PKG_LIST_PART_0}" =~ "${DEP}" ]]; then
      echo "Shard 0 failed to include dependency: ${DEP}"
      echo "@@@STEP_FAILURE@@@"
      exit 1
    fi
  done

  local DEPS=$(make -s PRINT_DEPS=1 ${PKG_LIST_PART_1})
  for DEP in ${DEPS}; do
    if [[ ! "${PKG_LIST_PART_1}" =~ "${DEP}" ]]; then
      echo "Shard 1 failed to include dependency: ${DEP}"
      echo "@@@STEP_FAILURE@@@"
      exit 1
    fi
  done

  # Define the third package list as the set of all package
  # not included in the first two lists.

  PKG_LIST_PART_2=""
  for PKG in ${ALL_PACKAGES}; do
    if [[ ! ${PKG_LIST_PART_0} =~ ${PKG} ]]; then
      if [[ ! ${PKG_LIST_PART_1} =~ ${PKG} ]]; then
          PKG_LIST_PART_2+=" ${PKG}"
      fi
    fi
  done
}

BuildSuccess() {
  echo "naclports: Install SUCCEEDED $1 ($NACL_ARCH)"
}

BuildFailure() {
  MESSAGE="naclports: Install FAILED for $1 ($NACL_ARCH)"
  echo $MESSAGE
  echo "@@@STEP_FAILURE@@@"
  MESSAGES="$MESSAGES\n$MESSAGE"
  RESULT=1
}

RunCmd() {
  echo $*
  $*
}

BuildPackage() {
  if RunCmd make $1 ; then
    BuildSuccess $1
  else
    # On cygwin retry each build 3 times before failing
    uname=$(uname -s)
    if [ ${uname:0:6} = "CYGWIN" ]; then
      echo "@@@STEP_WARNINGS@@@"
      for i in 1 2 3 ; do
        if make $1 ; then
          BuildSuccess $1
          return
        fi
      done
    fi
    BuildFailure $1
  fi
}
