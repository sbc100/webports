#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -x
set -e

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
export NACL_SDK_ROOT="${SCRIPT_DIR}/../"

RESULT=1

# TODO: Eliminate this dependency if possible.
# This is required on OSX so that the naclports version of pkg-config can be
# found.
export PATH=${PATH}:/opt/local/bin

StartBuild() {
  cd $2
  export NACL_PACKAGES_BITSIZE=$3
  echo "@@@BUILD_STEP $3-bit setup@@@"
  if ! ./$1 ; then
    RESULT=0
  fi
}

# Ignore 'periodic-' prefix.
BUILDBOT_BUILDERNAME=${BUILDBOT_BUILDERNAME#periodic-}

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
if [ "$LIBC" == "glibc" ]; then
  export NACL_GLIBC=1
elif [ "$LIBC" == "newlib" ]; then
  export NACL_GLIBC=0
else
  echo "Bad LIBC: ${LIBC}" 1>&2
  exit 1
fi

# Compute script name.
readonly SCRIPT_NAME="nacl-install-${BOT_OS_DIR}-ports-${SHARD}.sh"

# Goto src/
cd ${SCRIPT_DIR}/..

# Cleanup.
echo "@@@BUILD_STEP Cleanup@@@"
if ! make clean ; then
  echo "Error cleaning!" 1>&2
  exit 1
fi

# Install SDK.
echo "@@@BUILD_STEP Install Latest SDK@@@"
#${PYTHON} build_tools/buildbot_sdk_setup.py

# Build 32-bit.
StartBuild ${SCRIPT_NAME} ${SCRIPT_DIR}/bots/${BOT_OS_DIR} 32
if [[ $RESULT != 0 ]]; then
  # Build 64-bit.
  StartBuild ${SCRIPT_NAME} ${SCRIPT_DIR}/bots/${BOT_OS_DIR} 64
fi

exit 0
