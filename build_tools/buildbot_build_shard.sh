#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

######################################################################
# Notes on directory layout:
# makefile location (base_dir):  naclports/src
# toolchain injection point:     specified externally via NACL_SDK_ROOT.
######################################################################

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
source ${SCRIPT_DIR}/buildbot_common.sh

set -o nounset
set -o errexit

make clean
readonly PARTCMD="python build_tools/partition.py"
readonly SHARD_CMD="${PARTCMD} -t ${SHARD} -n ${SHARDS}"
echo "Calculating targets for shard ${SHARD} of ${SHARDS}"
readonly PACKAGE_LIST=$(${SHARD_CMD})
if [ -z "${PACKAGE_LIST}" ]; then
  echo "sharding command failed: ${SHARD_CMD}"
  exit 1
fi

echo "Building the following packages: ${PACKAGE_LIST}"
for PKG in ${PACKAGE_LIST}; do
  InstallPackage ${PKG}
done

echo "@@@BUILD_STEP ${NACL_ARCH} Summary@@@"
if [[ $RESULT != 0 ]] ; then
  echo "@@@STEP_FAILURE@@@"
  echo -e "$MESSAGES"
fi

exit $RESULT
