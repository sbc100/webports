#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Main entry point for buildbots.
# For local testing set BUILDBOT_BUILDERNAME and TEST_BUILDBOT, e.g:
#  export TEST_BUILDBOT=1
#  export BUILDBOT_BUILDERNAME=linux-newlib-0
#  ./buildbot_selector.sh

set -o errexit

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
export NACL_SDK_ROOT="$(dirname ${SCRIPT_DIR})/out/nacl_sdk"

RESULT=0

# TODO: Eliminate this dependency if possible.
# This is required on OSX so that the naclports version of pkg-config can be
# found.
export PATH=${PATH}:/opt/local/bin

StartBuild() {
  cd ${BOT_DIR}
  export NACL_ARCH=$2

  echo "@@@BUILD_STEP $2 setup@@@"
  if ! ./$1 ; then
    RESULT=1
  fi
}

# Ignore 'periodic-' prefix.
BUILDBOT_BUILDERNAME=${BUILDBOT_BUILDERNAME#periodic-}

# The SDK builder builds a subset of the ports, but with multiple
# configurations.
if [ "${BUILDBOT_BUILDERNAME}" = "linux-sdk" ]; then
  # Goto src/
  cd ${SCRIPT_DIR}/..

  if [ -z "${TEST_BUILDBOT:-}" -o ! -d ${NACL_SDK_ROOT} ]; then
    echo "@@@BUILD_STEP Install Latest SDK@@@"
    ${PYTHON} build_tools/download_sdk.py
  fi

  cd ${SCRIPT_DIR}/bots/linux
  ./naclports-linux-sdk-bundle.sh
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

# Install SDK.
echo "@@@BUILD_STEP Install Latest SDK@@@"
if [ -z "${TEST_BUILDBOT:-}" -o ! -d ${NACL_SDK_ROOT} ]; then
  ${PYTHON} build_tools/download_sdk.py
fi

# This a temporary hack until the pnacl support is more mature
if [ ${LIBC} = "pnacl_newlib" ] ; then
  BOT_DIR=${SCRIPT_DIR}/bots
  StartBuild pnacl_bots.sh pnacl
  exit 0
fi

# Compute script name.
readonly SCRIPT_NAME="naclports-${BOT_OS_DIR}-${SHARD}.sh"
BOT_DIR=${SCRIPT_DIR}/bots/${BOT_OS_DIR}

# Build 32-bit.
StartBuild ${SCRIPT_NAME} i686

# Build 64-bit.
StartBuild ${SCRIPT_NAME} x86_64

# Build ARM.
if [ ${NACL_GLIBC} != "1" ]; then
  StartBuild ${SCRIPT_NAME} arm
fi

exit $RESULT
