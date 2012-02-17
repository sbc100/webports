#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

######################################################################
# Notes on directory layout:
# makefile location (base_dir):  naclports/src
# bot script location:           naclports/src/build_tools/bots/
# toolchain injection point:     naclports/src/toolchain
######################################################################

set -o nounset
set -o errexit

readonly BASE_DIR="$(dirname $0)/../.."
cd ${BASE_DIR}

readonly SDK_VERSION=7819
readonly SDK_PLATFORM=linux_x86_64_adhoc_sdk
readonly SDK_URL=http://gsdview.appspot.com/nativeclient-archive2/toolchain/${SDK_VERSION}/naclsdk_pnacl_${SDK_PLATFORM}.tgz


ERROR=0

readonly PACKAGES=$(make works_for_pnacl_list)
export NACL_PACKAGES_BITSIZE=pnacl
export NACL_SDK_ROOT=$(readlink -e ${BASE_DIR})


StepConfig() {
  echo "@@@BUILD_STEP CONFIG"
  echo "BASE_DIR: ${BASE_DIR}"
  echo "SDK:      ${SDK_URL}"
  echo "PACKAGES:"
  for i in ${PACKAGES} ; do
    echo "    $i"
  done
}


StepInstallSdk() {
  echo "@@@BUILD_STEP INSTALL_SDK"
  dst=${BASE_DIR}/toolchain
  rm -rf ${dst}
  mkdir  -p ${dst}/pnacl_linux_x86_64
  wget ${SDK_URL} -O ${dst}/tarball.tgz
  tar zxvf $(readlink -e ${dst}/tarball.tgz) -C ${dst}/pnacl_linux_x86_64
}


StepBuildEverything() {
  local messages=""

  make clean
  for i in ${PACKAGES} ; do
    if make $i ; then
      echo "naclports build SUCCEDED for $i"
    else
      echo "naclports build FAILED for $i"
      echo "@@@STEP_FAILURE@@@"
      messages="${messages}\nfailure: $i"
      ERROR=1
    fi
  done

  echo "@@@BUILD_STEP Summary@@@"
  if [[ ${ERROR} != 0 ]] ; then
    echo "@@@STEP_FAILURE@@@"
  fi
  echo -e "${messages}"
}

StepConfig
StepInstallSdk
StepBuildEverything

exit ${ERROR}
