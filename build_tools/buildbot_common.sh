#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

RESULT=0
MESSAGES=

readonly BASE_DIR="$(dirname $0)/.."
cd ${BASE_DIR}

UPLOAD_PATH=nativeclient-mirror/naclports/${PEPPER_DIR}/
if [ -d .git ]; then
  UPLOAD_PATH+=`git number`-`git rev-parse --short HEAD`
else
  UPLOAD_PATH+=${BUILDBOT_GOT_REVISION}
fi

BuildSuccess() {
  echo "naclports: Build SUCCEEDED $1 ($NACL_ARCH)"
}

BuildFailure() {
  MESSAGE="naclports: Build FAILED for $1 ($NACL_ARCH)"
  echo $MESSAGE
  echo "@@@STEP_FAILURE@@@"
  MESSAGES="$MESSAGES\n$MESSAGE"
  RESULT=1
  if [ "${TEST_BUILDBOT:-}" = "1" ]; then
    exit 1
  fi
}

RunCmd() {
  echo $*
  $*
}

BuildPackage() {
  echo "@@@BUILD_STEP ${NACL_ARCH} ${TOOLCHAIN} $1@@@"
  if RunCmd build_tools/naclports.py build ports/$1 -v --ignore-disabled ; then
    BuildSuccess $1
  else
    BuildFailure $1
  fi
}

InstallPackage() {
  echo "@@@BUILD_STEP ${NACL_ARCH} ${TOOLCHAIN} $1@@@"
  export BUILD_FLAGS="-v --ignore-disabled"
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
