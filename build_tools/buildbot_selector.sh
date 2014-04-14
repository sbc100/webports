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
set -o nounset

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
DEFAULT_NACL_SDK_ROOT="$(dirname ${SCRIPT_DIR})/out/nacl_sdk"
NACL_SDK_ROOT=${NACL_SDK_ROOT:-${DEFAULT_NACL_SDK_ROOT}}
export NACL_SDK_ROOT

BOT_GSUTIL='/b/build/scripts/slave/gsutil'
if [ -e ${BOT_GSUTIL} ]; then
  export GSUTIL=${BOT_GSUTIL}
else
  export GSUTIL=gsutil
fi

# Allows Linux Chromium builds to use the existing SUID Sandbox on the bots.
# Ignored on other platforms.
export CHROME_DEVEL_SANDBOX=/opt/chromium/chrome_sandbox


# The bots set the BOTO_CONFIG environment variable to a different .boto file
# (currently /b/build/site-config/.boto). override this to the gsutil default
# which has access to gs://nativeclient-mirror.
# gsutil also looks for AWS_CREDENTIAL_FILE, so clear that too.
unset AWS_CREDENTIAL_FILE
unset BOTO_CONFIG

RESULT=0

# TODO: Eliminate this dependency if possible.
# This is required on OSX so that the naclports version of pkg-config can be
# found.
export PATH=${PATH}:/opt/local/bin

if [ "${TEST_BUILDBOT:-}" = "1" -a -z "${BUILDBOT_BUILDERNAME:-}" ]; then
  export BUILDBOT_BUILDERNAME=linux-newlib-0
fi

StartBuild() {
  export NACL_ARCH=$1
  export TOOLCHAIN
  export SHARD
  export SHARDS

  echo "@@@BUILD_STEP $1 setup@@@"
  if ! ./build_tools/buildbot_build_shard.sh ; then
    RESULT=1
  fi
}

Publish() {
  echo "@@@BUILD_STEP upload binaries@@@"
  echo "Uploading to ${UPLOAD_PATH}"

  ${GSUTIL} cp -R -a public-read out/publish/* gs://${UPLOAD_PATH}/publish/

  local URL="http://gsdview.appspot.com/${UPLOAD_PATH}/"
  echo "@@@STEP_LINK@browse@${URL}@@@"
}

if [[ ${BUILDBOT_BUILDERNAME} =~ periodic-* ]]; then
  NACLPORTS_NO_UPLOAD=1
fi

# Strip 'periodic-' prefix.
BUILDBOT_BUILDERNAME=${BUILDBOT_BUILDERNAME#periodic-}
PYTHON=python

if [ "${BUILDBOT_BUILDERNAME}" = "linux-sdk" ]; then
  readonly OS=linux
else
  # Decode buildername.
  readonly BNAME_REGEX="(nightly-)?(.+)-(.+)-(.+)"
  if [[ ${BUILDBOT_BUILDERNAME} =~ $BNAME_REGEX ]]; then
    readonly OS=${BASH_REMATCH[2]}
    readonly LIBC=${BASH_REMATCH[3]}
    readonly SHARD=${BASH_REMATCH[4]}
  else
    echo "Bad BUILDBOT_BUILDERNAME: ${BUILDBOT_BUILDERNAME}" 1>&2
    exit 1
  fi

  # Select platform specific things.
  if [ "$OS" = "win" ]; then
    PYTHON=python.bat
  fi

  # Select libc
  if [ "$LIBC" = "glibc" ]; then
    TOOLCHAIN=glibc
  elif [ "$LIBC" = "newlib" ]; then
    TOOLCHAIN=newlib
  elif [ "$LIBC" = "pnacl_newlib" ]; then
    TOOLCHAIN=pnacl
  elif [ "$LIBC" = "bionic" ]; then
    TOOLCHAIN=bionic
  else
    echo "Bad LIBC: ${LIBC}" 1>&2
    exit 1
  fi

  # Select shard count
  if [ "$OS" = "mac" ]; then
    readonly SHARDS=2
  elif [ "$OS" = "linux" ]; then
    if [ "$TOOLCHAIN" = "glibc" ]; then
      readonly SHARDS=4
    elif [ "$TOOLCHAIN" = "newlib" ]; then
      readonly SHARDS=3
    elif [ "$TOOLCHAIN" = "bionic" ]; then
      readonly SHARDS=1
    elif [ "$TOOLCHAIN" = "pnacl" ]; then
      readonly SHARDS=4
    else
      echo "Unspecified sharding for TOOLCHAIN: ${TOOLCHAIN}" 1>&2
    fi
  else
    echo "Unspecified sharding for OS: ${OS}" 1>&2
  fi
fi

# Install SDK.
if [ -z "${TEST_BUILDBOT:-}" -o ! -d ${NACL_SDK_ROOT} ]; then
  echo "@@@BUILD_STEP Install Latest SDK@@@"
  ${PYTHON} ${SCRIPT_DIR}/download_sdk.py
fi

# Test browser testing harness.
PlumbingTests() {
  echo "@@@BUILD_STEP plumbing_tests i686@@@"
  if ! ${PYTHON} ${SCRIPT_DIR}/../chrome_test/plumbing_test.py \
      -a i686 -x -vv; then
    RESULT=1
    echo "@@@STEP_FAILURE@@@"
  fi
  if [ "$OS" = "linux" ]; then
    echo "@@@BUILD_STEP plumbing_tests x86_64@@@"
    if ! ${PYTHON} ${SCRIPT_DIR}/../chrome_test/plumbing_test.py \
        -a x86_64 -x -vv; then
      RESULT=1
      echo "@@@STEP_FAILURE@@@"
    fi
  fi
}

PlumbingTests

# PEPPER_DIR is the root direcotry name within the bundle. e.g. pepper_28
export PEPPER_VERSION=$(${NACL_SDK_ROOT}/tools/getos.py --sdk-version)
export PEPPER_DIR=pepper_${PEPPER_VERSION}
export NACLPORTS_ANNOTATE=1
. ${SCRIPT_DIR}/buildbot_common.sh

# The SDK builder builds a subset of the ports, but with multiple
# configurations.
if [ "${BUILDBOT_BUILDERNAME}" = "linux-sdk" ]; then
  cd ${SCRIPT_DIR}
  ./buildbot_sdk_bundle.sh
  exit 0
fi

if [ "${LIBC}" = "pnacl_newlib" ] ; then
  StartBuild pnacl
else
  if [ "${TOOLCHAIN}" != "bionic" ]; then
    # Build 32-bit.
    StartBuild i686

    # Build 64-bit.
    StartBuild x86_64
  fi

  # Build ARM.
  if [ "${TOOLCHAIN}" != "glibc" ]; then
    StartBuild arm
  fi
fi

# Publish resulting builds to Google Storage, but only on the
# linux bots.
if [ -z "${NACLPORTS_NO_UPLOAD:-}" -a "$OS" = "linux" ]; then
  Publish
fi

echo "@@@BUILD_STEP Summary@@@"
if [ "${RESULT}" != "0" ] ; then
  echo "@@@STEP_FAILURE@@@"
  echo -e "${MESSAGES}"
fi

exit ${RESULT}
