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

  # These lists should be topologically sorted by dependency; i.e., each
  # package should only depend on the packages before it in the list.
  PKG_LIST_PART_0="
    bzip2
    zlib
    boost
    glibc-compat
    openssl
    libogg
    libvorbis
    lame
    libav
    OpenSceneGraph
    ncurses
    readline
    sqlite
    FreeImage
    fftw
    curl
    flac
    tiff
    openal-soft
    mpg123
    jpeg8d
    libpng
    libmng
    lcms
    DevIL
    cfitsio
    faad2
    speex
    webp
    libhangul
    faac
    gc
    jsoncpp
    freealut
    tinyxml
    openal-ogg
    thttpd
    dreadthread
  "

  PKG_LIST_PART_1="
    zlib
    libpng
    Regal
    glibc-compat
    ncurses
    readline
    ruby
    python
    glib
    libtar
    nethack
    SDL
    nacl-mounts
    dosbox
    libogg
    libvorbis
    scummvm
    vim
    protobuf
    libmikmod
    freetype
    SDL_ttf
    SDL_mixer
    metakit
    expat
    drod
    bochs
    xaos
    nano
    python_ppapi
    x264
    agg
    libtomcrypt
    ruby_ppapi
    SDL_net
    jpeg8d
    SDL_image
    snes9x
  "

  if [ -n "${TEST_BUILDBOT:-}" ]; then
    # In testing mode just build small set of packages.
    PKG_LIST_PART_0="
      glibc-compat
      ncurses
      readline
      libtar
      zlib
      lua5.2
      lua_ppapi
    "
  fi

  for PKG in ${PKG_LIST_PART_0} ${PKG_LIST_PART_1}; do
    if [[ ! "${ALL_PACKAGES}" =~ "${PKG}" ]]; then
      echo "bot_common.sh: Invalid package name: ${PKG}"
      echo "@@@STEP_FAILURE@@@"
      exit 1
    fi
  done

  local DEPS=$(make -s PRINT_DEPS=1 ${PKG_LIST_PART_0})
  for DEP in ${DEPS}; do
    if [[ ! "${PKG_LIST_PART_0}" =~ "${DEP}" ]]; then
      echo "bot_common.sh: Shard 0 failed to include dependency: ${DEP}"
      echo "@@@STEP_FAILURE@@@"
      exit 1
    fi
  done

  local DEPS=$(make -s PRINT_DEPS=1 ${PKG_LIST_PART_1})
  for DEP in ${DEPS}; do
    if [[ ! "${PKG_LIST_PART_1}" =~ "${DEP}" ]]; then
      echo "bot_common.sh: Shard 1 failed to include dependency: ${DEP}"
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
