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
  if ! $1 ; then
    RESULT=0
  fi
}

BUILDBOT_BUILDERNAME=${BUILDBOT_BUILDERNAME#periodic-}

if [ ${BUILDBOT_BUILDERNAME} = linux-ports-0 ] ; then
  StartBuild "./nacl-install-linux-ports-0.sh" ${SCRIPT_DIR}/bots/linux 32
  if [[ $RESULT != 0 ]]; then
    StartBuild "./nacl-install-linux-ports-0.sh" ${SCRIPT_DIR}/bots/linux 64
  fi
elif [ ${BUILDBOT_BUILDERNAME} = linux-ports-1 ] ; then
  StartBuild "./nacl-install-linux-ports-1.sh" ${SCRIPT_DIR}/bots/linux 32
  if [[ $RESULT != 0 ]]; then
    StartBuild "./nacl-install-linux-ports-1.sh" ${SCRIPT_DIR}/bots/linux 64
  fi
elif [ ${BUILDBOT_BUILDERNAME} = linux-ports-2 ] ; then
  StartBuild "./nacl-install-linux-ports-2.sh" ${SCRIPT_DIR}/bots/linux 32
  if [[ $RESULT != 0 ]]; then
    StartBuild "./nacl-install-linux-ports-2.sh" ${SCRIPT_DIR}/bots/linux 64
  fi
elif [ ${BUILDBOT_BUILDERNAME} = mac-ports-0 ] ; then
  StartBuild "./nacl-install-mac-ports-0.sh" ${SCRIPT_DIR}/bots/mac 32
  if [[ $RESULT != 0 ]]; then
    StartBuild "./nacl-install-mac-ports-0.sh" ${SCRIPT_DIR}/bots/mac 64
  fi
elif [ ${BUILDBOT_BUILDERNAME} = mac-ports-1 ] ; then
  StartBuild "./nacl-install-mac-ports-1.sh" ${SCRIPT_DIR}/bots/mac 32
  if [[ $RESULT != 0 ]]; then
    StartBuild "./nacl-install-mac-ports-1.sh" ${SCRIPT_DIR}/bots/mac 64
  fi
elif [ ${BUILDBOT_BUILDERNAME} = mac-ports-2 ] ; then
  StartBuild "./nacl-install-mac-ports-2.sh" ${SCRIPT_DIR}/bots/mac 32
  if [[ $RESULT != 0 ]]; then
    StartBuild "./nacl-install-mac-ports-2.sh" ${SCRIPT_DIR}/bots/mac 64
  fi
elif [ ${BUILDBOT_BUILDERNAME} = windows-ports-0 ] ; then
  StartBuild "./nacl-install-windows-ports-0.sh" ${SCRIPT_DIR}/bots/windows 32
  if [[ $RESULT != 0 ]]; then
    StartBuild "./nacl-install-windows-ports-0.sh" ${SCRIPT_DIR}/bots/windows 64
  fi
elif [ ${BUILDBOT_BUILDERNAME} = windows-ports-1 ] ; then
  StartBuild "./nacl-install-windows-ports-1.sh" ${SCRIPT_DIR}/bots/windows 32
  if [[ $RESULT != 0 ]]; then
    StartBuild "./nacl-install-windows-ports-1.sh" ${SCRIPT_DIR}/bots/windows 64
  fi
elif [ ${BUILDBOT_BUILDERNAME} = windows-ports-2 ] ; then
  StartBuild "./nacl-install-windows-ports-2.sh" ${SCRIPT_DIR}/bots/windows 32
  if [[ $RESULT != 0 ]]; then
    StartBuild "./nacl-install-windows-ports-2.sh" ${SCRIPT_DIR}/bots/windows 64
  fi
elif [ ${BUILDBOT_BUILDERNAME} = windows-ports-3 ] ; then
  StartBuild "./nacl-install-windows-ports-3.sh" ${SCRIPT_DIR}/bots/windows 32
  if [[ $RESULT != 0 ]]; then
    StartBuild "./nacl-install-windows-ports-3.sh" ${SCRIPT_DIR}/bots/windows 64
  fi
elif [ ${BUILDBOT_BUILDERNAME} = windows-ports-4 ] ; then
  StartBuild "./nacl-install-windows-ports-4.sh" ${SCRIPT_DIR}/bots/windows 32
  if [[ $RESULT != 0 ]]; then
    StartBuild "./nacl-install-windows-ports-4.sh" ${SCRIPT_DIR}/bots/windows 64
  fi
elif [ ${BUILDBOT_BUILDERNAME} = windows-ports-5 ] ; then
  StartBuild "./nacl-install-windows-ports-5.sh" ${SCRIPT_DIR}/bots/windows 32
  if [[ $RESULT != 0 ]]; then
    StartBuild "./nacl-install-windows-ports-5.sh" ${SCRIPT_DIR}/bots/windows 64
  fi
elif [ ${BUILDBOT_BUILDERNAME} = windows-ports-6 ] ; then
  StartBuild "./nacl-install-windows-ports-6.sh" ${SCRIPT_DIR}/bots/windows 32
  if [[ $RESULT != 0 ]]; then
    StartBuild "./nacl-install-windows-ports-6.sh" ${SCRIPT_DIR}/bots/windows 64
  fi
else
  cd ${SCRIPT_DIR}/..
  export NACL_PACKAGES_BITSIZE=32
  make clean
  if ! make all ; then
    echo "Error building for 32-bits." 1>&2
    exit 1
  fi
  export NACL_PACKAGES_BITSIZE=64
  if ! make all ; then
    echo "Error building for 64-bits." 1>&2
    exit 1
  fi
fi

exit 0
