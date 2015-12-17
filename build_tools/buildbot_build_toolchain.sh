#!/bin/bash
# Copyright (c) 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
source ${SCRIPT_DIR}/buildbot_common.sh

TOOLCHAIN_PACKAGES="pnacl"

for TOOLCHAIN in glibc clang-newlib pnacl emscripten; do
  for pkg in ${TOOLCHAIN_PACKAGES}; do
    InstallPackageMultiArch ${pkg}
  done
done

echo "@@@BUILD_STEP Summary@@@"
if [[ ${RESULT} != 0 ]] ; then
  echo "@@@STEP_FAILURE@@@"
  echo -e "${MESSAGES}"
fi

exit ${RESULT}
