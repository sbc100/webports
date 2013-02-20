#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# linux_sdk.sh
#
# usage:  linux_sdk.sh
#
# This script builds the packages that will be bundled with the NaCl SDK.
#

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"

source ${SCRIPT_DIR}/../bot_common.sh

OUT_DIR=${SCRIPT_DIR}/../../../out
OUT_BUNDLE_DIR=${OUT_DIR}/sdk_bundle/pepper_XX/ports

cd ${SCRIPT_DIR}/../../..
make clean
PACKAGES=$(make sdklibs_list)

# $1 - name of package
# $2 - arch to build for
# $3 - 'glibc' or 'newlib'
# $4 - 'Debug' or 'Release'
CustomBuildPackage() {
  export NACLPORTS_PREFIX=${OUT_DIR}/sdk_bundle/build/$2_$3_$4
  export NACL_ARCH=$2

  if [ "$3" = "glibc" ]; then
    export NACL_GLIBC=1
  else
    export NACL_GLIBC=0
  fi

  if [ "$4" = "Debug" ]; then
    export NACL_DEBUG=1
  else
    export NACL_DEBUG=0
  fi

  BuildPackage $1
}

# $1 - name of package
# $2 - arch to build for
BuildPackageArchAll() {
  local PACKAGE=$1
  local ARCH=$2
  CustomBuildPackage $PACKAGE $ARCH newlib Release
  CustomBuildPackage $PACKAGE $ARCH newlib Debug
  if [ "$ARCH" != "arm" ]; then
    CustomBuildPackage $PACKAGE $ARCH glibc Release
    CustomBuildPackage $PACKAGE $ARCH glibc Debug
  fi
}

# $1 - name of package
BuildPackageAll() {
  local PACKAGE=$1
  BuildPackageArchAll $PACKAGE i686
  BuildPackageArchAll $PACKAGE x86_64
  BuildPackageArchAll $PACKAGE arm
  echo "naclports Install SUCCEEDED $PACKAGE"
}

MoveLibs() {
  for ARCH in i686 x86_64 arm; do
    if [ "$ARCH" = "i686" ]; then
      ARCH_DIR=x86_32
    else
      ARCH_DIR=$ARCH
    fi

    if [ "$ARCH" = "arm" ]; then
      LIBC_VARIANTS="newlib"
    else
      LIBC_VARIANTS="newlib glibc"
    fi

    for LIBC in $LIBC_VARIANTS; do
      for CONFIG in Debug Release; do
        # Copy build results to destination directories.
        SRC_DIR=${OUT_DIR}/sdk_bundle/build/${ARCH}_${LIBC}_${CONFIG}

        # copy includes
        cp -d -r ${SRC_DIR}/include ${OUT_BUNDLE_DIR}

        # copy libs
        ARCH_LIB_DIR=${OUT_BUNDLE_DIR}/lib/${LIBC}_${ARCH_DIR}/${CONFIG}
        mkdir -p ${ARCH_LIB_DIR}
        for FILE in ${SRC_DIR}/lib/* ; do
          EXT="${FILE##*.}"
          if [[ ( -f "${FILE}" || -L "${FILE}" ) && "${EXT}" != "la" ]]; then
            cp -d -r ${FILE} ${ARCH_LIB_DIR}
          fi
        done

      done
    done
  done
}

for package in $PACKAGES; do
  BuildPackageAll $package
done

echo "@@@BUILD_STEP copy to bundle@@@"
for package in $PACKAGES; do
  MoveLibs $package
done

echo "@@@BUILD_STEP summary@@@"
if [[ $RESULT != 0 ]] ; then
  echo "@@@STEP_FAILURE@@@"
fi

echo -e "$MESSAGES"

exit $RESULT
