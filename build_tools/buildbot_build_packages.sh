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

BuildNaclMounts() {
  cd ${SCRIPT_DIR}/../packages/scripts/nacl-mounts
  echo "@@@BUILD_STEP nacl-mounts test@@@"
  make clean && make all && ./tests_out/nacl_mounts_tests
}

StartBuild() {
  cd $2
  export NACL_PACKAGES_BITSIZE=$3
  if ! $1 ; then
    RESULT=0
  fi
}

if [ ${BUILDBOT_BUILDERNAME} = linux-ports-0 ] ; then
  StartBuild "./nacl-install-linux-ports-0.sh" ${SCRIPT_DIR}/bots/linux 32
  if [[ $RESULT != 1 ]]; then
    StartBuild "./nacl-install-linux-ports-0.sh" ${SCRIPT_DIR}/bots/linux 64
  fi
elif [ ${BUILDBOT_BUILDERNAME} = linux-ports-1 ] ; then
  StartBuild "./nacl-install-linux-ports-1.sh" ${SCRIPT_DIR}/bots/linux 32
  if [[ $RESULT != 1 ]]; then
    StartBuild "./nacl-install-linux-ports-1.sh" ${SCRIPT_DIR}/bots/linux 64
  fi
elif [ ${BUILDBOT_BUILDERNAME} = linux-ports-2 ] ; then
  BuildNaclMounts
  StartBuild "./nacl-install-linux-ports-2.sh" ${SCRIPT_DIR}/bots/linux 32
  if [[ $RESULT != 1 ]]; then
    StartBuild "./nacl-install-linux-ports-2.sh" ${SCRIPT_DIR}/bots/linux 64
  fi
else
  BuildNaclMounts
  cd ${SCRIPT_DIR}/../packages
  if ! "./nacl-install-all.sh" ; then
    echo "Error building!" 1>&2
    exit 1
  fi
fi

exit 0
