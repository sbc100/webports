#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

######################################################################
# Notes on directory layout:
# makefile location (base_dir):  naclports/src
# toolchain injection point:     specified externally via NACL_SDK_ROOT.
######################################################################

set -o nounset
set -o errexit

RESULT=0
MESSAGES=

readonly BASE_DIR="$(dirname $0)/.."
cd ${BASE_DIR}

BuildSuccess() {
  echo "naclports: Build SUCCEEDED $1 ($NACL_ARCH)"
}

BuildFailure() {
  MESSAGE="naclports: Build FAILED for $1 ($NACL_ARCH)"
  echo $MESSAGE
  echo "@@@STEP_FAILURE@@@"
  MESSAGES="$MESSAGES\n$MESSAGE"
  RESULT=1
}

RunCmd() {
  echo $*
  $*
}

BuildPackage() {
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

make clean
readonly PARTCMD="python build_tools/partition.py"
readonly PACKAGE_LIST=$(${PARTCMD} -t ${SHARD} -n ${SHARDS})
for PKG in ${PACKAGE_LIST}; do
  BuildPackage ${PKG}
done

echo "@@@BUILD_STEP ${NACL_ARCH} Summary@@@"
if [[ $RESULT != 0 ]] ; then
  echo "@@@STEP_FAILURE@@@"
  echo -e "$MESSAGES"
fi

exit $RESULT
