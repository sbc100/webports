#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -x
set -e

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
export NACL_SDK_ROOT="${SCRIPT_DIR}/../pepper_XX"

RESULT=1

# TODO: Eliminate this dependency if possible.
# This is required on OSX so that the naclports version of pkg-config can be
# found.
export PATH=${PATH}:/opt/local/bin

StartBuild() {
  cd $2
  export NACL_ARCH=$3
  echo "@@@BUILD_STEP $3 setup@@@"
  if ! ./$1 ; then
    RESULT=0
  fi
}

# Ignore 'periodic-' prefix.
BUILDBOT_BUILDERNAME=${BUILDBOT_BUILDERNAME#periodic-}

# The SDK builder builds a subset of the ports, but with multiple
# configurations.
if [ ${BUILDBOT_BUILDERNAME} = "linux-sdk" ]; then
  cd ${SCRIPT_DIR}/bots/linux
  ./nacl-linux-sdk-bundle.sh
  exit 0
fi

# Decode buildername.
readonly BNAME_REGEX="(.+)-(.+)-(.+)"
if [[ ${BUILDBOT_BUILDERNAME} =~ $BNAME_REGEX ]]; then
  readonly OS=${BASH_REMATCH[1]}
  readonly LIBC=${BASH_REMATCH[2]}
  readonly SHARD=${BASH_REMATCH[3]}
else
  echo "Bad BUILDBOT_BUILDERNAME: ${BUILDBOT_BUILDERNAME}" 1>&2
  exit 1
fi

# Select platform specific things.
if [ "$OS" = "mac" ]; then
  readonly PYTHON=python
  # Use linux config on mac too.
  readonly BOT_OS_DIR=linux
elif [ "$OS" = "linux" ]; then
  readonly PYTHON=python
  readonly BOT_OS_DIR=linux
elif [ "$OS" = "win" ]; then
  readonly PYTHON=python.bat
  readonly BOT_OS_DIR=windows
else
  echo "Bad OS: ${OS}" 1>&2
  exit 1
fi

# Select libc
if [ "$LIBC" = "glibc" ]; then
  export NACL_GLIBC=1
elif [ "$LIBC" = "newlib" ]; then
  export NACL_GLIBC=0
elif [ "$LIBC" = "pnacl_newlib" ]; then
  export NACL_GLIBC=0
else
  echo "Bad LIBC: ${LIBC}" 1>&2
  exit 1
fi

# Goto src/
cd ${SCRIPT_DIR}/..

# Cleanup.
echo "@@@BUILD_STEP Cleanup@@@"
make clean

# Install SDK.
echo "@@@BUILD_STEP Install Latest SDK@@@"
ls
ls build_tools
ls build_tools/download_sdk.py

${PYTHON} build_tools/download_sdk.py

# This a temporary hack until the pnacl support is more mature
if [ ${LIBC} = "pnacl_newlib" ] ; then
  ${SCRIPT_DIR}/bots/pnacl_bots.sh
  exit 0
fi

# Compute script name.
readonly SCRIPT_NAME="nacl-install-${BOT_OS_DIR}-ports-${SHARD}.sh"

# Build 32-bit.
StartBuild ${SCRIPT_NAME} ${SCRIPT_DIR}/bots/${BOT_OS_DIR} i686
if [[ $RESULT != 0 ]]; then
  # Build 64-bit.
  StartBuild ${SCRIPT_NAME} ${SCRIPT_DIR}/bots/${BOT_OS_DIR} x86_64
fi

exit 0
