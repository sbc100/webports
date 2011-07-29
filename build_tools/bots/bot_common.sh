#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# The nacl-install-{linux,mac,windows}-*.sh scripts should source this script.
#

set -o nounset
set -o errexit

RESULT=0
MESSAGES=

BuildSuccess() {
  echo "naclports nacl-install-all: Install SUCCEEDED $1 \
($NACL_PACKAGES_BITSIZE)"
}

BuildFailure() {
  MESSAGE="naclports nacl-install-all: Install FAILED for $1 \
($NACL_PACKAGES_BITSIZE)"
  echo $MESSAGE
  echo "@@@STEP_FAILURE@@@"
  MESSAGES="$MESSAGES\n$MESSAGE"
  RESULT=1
}

BuildPackage() {
  echo "@@@BUILD_STEP $NACL_PACKAGES_BITSIZE-bit $1@@@"
  if make $1 ; then
    BuildSuccess $1
  else
    if [ ${BUILDBOT_BUILDERNAME:0:3} = win ] ; then
      echo " @@@STEP_WARNINGS@@@"
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

BuildExample() {
  echo "@@@BUILD_STEP $NACL_PACKAGES_BITSIZE-bit $2@@@"
  readonly CURR_DIR=$(cd "$(dirname "$0")" ; pwd)
  cd ../examples/$1
  if ./nacl-$2.sh ; then
    BuildSuccess $2
  else
    BuildFailure $2
  fi
  cd ${CURR_DIR}
}
