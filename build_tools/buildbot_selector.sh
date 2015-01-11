#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Main entry point for buildbots.
# For local testing set BUILDBOT_BUILDERNAME and TEST_BUILDBOT, e.g:
#  TEST_BUILDBOT=1 BUILDBOT_BUILDERNAME=linux-newlib-0 ./buildbot_selector.sh

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

# The bots set the BOTO_CONFIG environment variable to a different .boto file
# (currently /b/build/site-config/.boto). override this to the gsutil default
# which has access to gs://naclports.
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

BuildShard() {
  export TOOLCHAIN
  export SHARD
  export SHARDS

  echo "@@@BUILD_STEP setup@@@"
  if ! ./build_tools/buildbot_build_shard.sh ; then
    RESULT=1
  fi
}

Publish() {
  echo "@@@BUILD_STEP upload binaries@@@"

  if [ "$(ls out/publish)" != "" ]; then
    echo "Uploading publish directory to ${UPLOAD_PATH}"
    ${GSUTIL} cp -R -a public-read out/publish/* gs://${UPLOAD_PATH}/publish/
  else
    echo "Nothing to upload in publish directory."
  fi

  if [ "$(ls out/packages)" != "" ]; then
    echo "Uploading packages directory to ${UPLOAD_PATH}"
    ${GSUTIL} cp -R -a public-read out/packages/* gs://${UPLOAD_PATH}/packages/
  else
    echo "Nothing to upload in packages directory."
  fi

  local URL="http://gsdview.appspot.com/${UPLOAD_PATH}/"
  echo "@@@STEP_LINK@browse@${URL}@@@"
}

# Strip 'periodic-' prefix.
BUILDBOT_BUILDERNAME=${BUILDBOT_BUILDERNAME#periodic-}
PYTHON=${SCRIPT_DIR}/python_wrapper

if [ "${BUILDBOT_BUILDERNAME}" = "linux-sdk" ]; then
  readonly OS=linux
else
  # Decode buildername.
  readonly BNAME_REGEX="(nightly-|naclports-)?(.+)-(.+)-(.+)"
  if [[ ${BUILDBOT_BUILDERNAME} =~ ${BNAME_REGEX} ]]; then
    readonly PREFIX=${BASH_REMATCH[1]}
    if [ "${PREFIX}" = "naclports-" ]; then
      readonly TRYBOT=1
      readonly NIGHTLY=0
    elif [ "${PREFIX}" = "nightly-" ]; then
      readonly TRYBOT=0
      readonly NIGHTLY=1
    else
      readonly TRYBOT=0
      readonly NIGHTLY=0
    fi
    readonly OS=${BASH_REMATCH[2]}
    readonly LIBC=${BASH_REMATCH[3]}
    readonly SHARD=${BASH_REMATCH[4]}
  else
    echo "Bad BUILDBOT_BUILDERNAME: ${BUILDBOT_BUILDERNAME}" 1>&2
    exit 1
  fi

  # Don't upload periodic or trybot builds.
  if [ "${TRYBOT}" = "1" -o "${NIGHTLY}" = "1" ]; then
    NACLPORTS_NO_UPLOAD=1
  fi

  # Select platform specific things.
  if [ "${OS}" = "win" ]; then
    PYTHON=python.bat
  fi

  # Select libc
  if [ "${LIBC}" = "glibc" ]; then
    TOOLCHAIN=glibc
  elif [ "${LIBC}" = "newlib" ]; then
    TOOLCHAIN=newlib
  elif [ "${LIBC}" = "pnacl_newlib" ]; then
    TOOLCHAIN=pnacl
  elif [ "${LIBC}" = "bionic" ]; then
    TOOLCHAIN=bionic
  else
    echo "Bad LIBC: ${LIBC}" 1>&2
    exit 1
  fi

  # Select shard count
  if [ "${OS}" = "mac" ]; then
    SHARDS=2
  elif [ "${OS}" = "linux" ]; then
    if [ "${TOOLCHAIN}" = "glibc" ]; then
      SHARDS=4
    elif [ "${TOOLCHAIN}" = "newlib" ]; then
      SHARDS=3
    elif [ "${TOOLCHAIN}" = "bionic" ]; then
      SHARDS=1
    elif [ "${TOOLCHAIN}" = "pnacl" ]; then
      SHARDS=4
    else
      echo "Unspecified sharding for TOOLCHAIN: ${TOOLCHAIN}" 1>&2
    fi
  else
    echo "Unspecified sharding for OS: ${OS}" 1>&2
  fi

  # For the trybots we have 5 shards for each toolchain
  if [ "${TRYBOT}" = "1" ]; then
    SHARDS=5
  fi
fi

# Optional Clobber (if checked in the buildbot ui).
if [ "${BUILDBOT_CLOBBER:-}" = "1" ]; then
  echo "@@@BUILD_STEP Clobber@@@"
  rm -rf out/
fi

# Install SDK.
if [ -z "${TEST_BUILDBOT:-}" -o ! -d ${NACL_SDK_ROOT} ]; then
  echo "@@@BUILD_STEP Install Latest SDK@@@"
  ARGS=""
  if [ ${TOOLCHAIN:-} = bionic ]; then
    ARGS="--bionic"
  fi
  echo ${PYTHON} ${SCRIPT_DIR}/download_sdk.py ${ARGS}
  ${PYTHON} ${SCRIPT_DIR}/download_sdk.py ${ARGS}
fi

Unittests() {
  echo "@@@BUILD_STEP naclports unittests@@@"
  CMD="make -C $(dirname ${SCRIPT_DIR}) check"
  echo "Running ${CMD}"
  if ! ${CMD}; then
    RESULT=1
    echo "@@@STEP_FAILURE@@@"
  fi
}

# Test browser testing harness.
PlumbingTests() {
  echo "@@@BUILD_STEP plumbing_tests i686@@@"
  if ! ${PYTHON} ${SCRIPT_DIR}/../chrome_test/plumbing_test.py \
      -a i686 -x -vv; then
    RESULT=1
    echo "@@@STEP_FAILURE@@@"
  fi
  if [ "${OS}" = "linux" ]; then
    echo "@@@BUILD_STEP plumbing_tests x86_64@@@"
    if ! ${PYTHON} ${SCRIPT_DIR}/../chrome_test/plumbing_test.py \
        -a x86_64 -x -vv; then
      RESULT=1
      echo "@@@STEP_FAILURE@@@"
    fi
  fi
}

Unittests
if [ -z "${TEST_BUILDBOT:-}" ]; then
  PlumbingTests
fi

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

CleanCurrentToolchain
BuildShard

# Publish resulting builds to Google Storage, but only on the
# linux bots.
if [ -z "${NACLPORTS_NO_UPLOAD:-}" -a "${OS}" = "linux" ]; then
  Publish
fi

echo "@@@BUILD_STEP Summary@@@"
if [ "${RESULT}" != "0" ] ; then
  echo "@@@STEP_FAILURE@@@"
  echo -e "${MESSAGES}"
fi

exit ${RESULT}
