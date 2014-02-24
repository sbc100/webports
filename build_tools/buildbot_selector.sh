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

BOT_GSUTIL='/b/build/scripts/slave/gsutil'
if [ -e ${BOT_GSUTIL} ]; then
  export GSUTIL=${BOT_GSUTIL}
else
  export GSUTIL=gsutil
fi


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

StartBuild() {
  export NACL_ARCH=$1
  export SHARD
  export SHARDS

  echo "@@@BUILD_STEP $1 setup@@@"
  # Goto src/
  cd ${SCRIPT_DIR}/..
  if ! ./build_tools/build_shard.sh ; then
    RESULT=1
  fi
  cd -
}

Publish() {
  if [ -n "${NACLPORTS_NO_UPLOAD:-}" ]; then
    return
  fi
  echo "@@@BUILD_STEP upload binaries@@@"
  UPLOAD_PATH=nativeclient-mirror/naclports/${PEPPER_DIR}/
  UPLOAD_PATH+=${BUILDBOT_GOT_REVISION}/publish
  SRC_PATH=out/publish
  echo "Uploading to ${UPLOAD_PATH}"

  ${GSUTIL} cp -R -a public-read ${SRC_PATH}/* gs://${UPLOAD_PATH}/

  URL="http://gsdview.appspot.com/${UPLOAD_PATH}/"
  echo "@@@STEP_LINK@browse@${URL}@@@"
}

if [[ ${BUILDBOT_BUILDERNAME} =~ periodic-* ]]; then
  readonly PERIODIC=1
else
  readonly PERIODIC=0
fi

# Strip 'periodic-' prefix.
BUILDBOT_BUILDERNAME=${BUILDBOT_BUILDERNAME#periodic-}

if [ "${BUILDBOT_BUILDERNAME}" != "linux-sdk" ]; then
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
  elif [ "$LIBC" = "bionic" ]; then
    export NACL_GLIBC=0
  else
    echo "Bad LIBC: ${LIBC}" 1>&2
    exit 1
  fi

  # Select shard count
  if [ "$OS" = "mac" ]; then
    readonly SHARDS=1
  elif [ "$OS" = "linux" ]; then
    if [ "$LIBC" = "glibc" ]; then
      readonly SHARDS=4
    elif [ "$LIBC" = "newlib" ]; then
      readonly SHARDS=3
    elif [ "$LIBC" = "bionic" ]; then
      readonly SHARDS=1
    elif [ "$LIBC" = "pnacl_newlib" ]; then
      readonly SHARDS=4
    else
      echo "Unspecified sharding for LIBC: ${LIBC}" 1>&2
    fi
  else
    echo "Unspecified sharding for OS: ${OS}" 1>&2
  fi
fi

# Goto src/
cd ${SCRIPT_DIR}/..

# Install SDK.
echo "@@@BUILD_STEP Install Latest SDK@@@"
if [ -z "${TEST_BUILDBOT:-}" -o ! -d ${NACL_SDK_ROOT} ]; then
  ${PYTHON} build_tools/download_sdk.py
fi

# PEPPER_DIR is the root direcotry name within the bundle. e.g. pepper_28
export PEPPER_VERSION=$(${NACL_SDK_ROOT}/tools/getos.py --sdk-version)
export PEPPER_DIR=pepper_${PEPPER_VERSION}
export NACLPORTS_ANNOTATE=1

# The SDK builder builds a subset of the ports, but with multiple
# configurations.
if [ "${BUILDBOT_BUILDERNAME}" = "linux-sdk" ]; then
  cd ${SCRIPT_DIR}
  ./naclports-linux-sdk-bundle.sh
  exit 0
fi

if [ ${LIBC} = "pnacl_newlib" ] ; then
  StartBuild pnacl
else
  # Build 32-bit.
  StartBuild i686

  # Build 64-bit.
  StartBuild x86_64

  # Build ARM.
  if [ ${NACL_GLIBC} != "1" ]; then
    StartBuild arm
  fi
fi

if [ ${PERIODIC} != "1" ]; then
  Publish
fi

exit $RESULT
