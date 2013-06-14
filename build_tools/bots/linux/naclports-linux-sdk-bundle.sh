#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# This script builds the packages that will be bundled with the NaCl SDK.

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"

source ${SCRIPT_DIR}/../bot_common.sh

NACLPORTS_ROOT="$(cd ${SCRIPT_DIR}/../../.. && pwd)"
OUT_DIR=${NACLPORTS_ROOT}/out

# On the naclports builders NACL_SDK_ROOT is a symlink called
# pepper_XX that points to the real NACL_SDK_ROOT of the
# downloaded SDK.  In this case we want to follow the link
# so that the ports bundle can be built into a folder with
# the same name (not just pepper_XX)
if [ -L "${NACL_SDK_ROOT}" ]; then
  NACL_SDK_ROOT=$(readlink ${NACL_SDK_ROOT})
fi

# PEPPER_DIR is the root direcotry name within the bundle. e.g. pepper_28
PEPPER_DIR=$(basename ${NACL_SDK_ROOT})
OUT_BUNDLE_DIR=${OUT_DIR}/sdk_bundle
OUT_PORTS_DIR=${OUT_BUNDLE_DIR}/${PEPPER_DIR}/ports

# The bots set the BOTO_CONFIG environment variable to a different .boto file
# (currently /b/build/site-config/.boto). override this to the gsutil default
# which has access to gs://nativeclient-mirror.
BOTO_CONFIG='~/.boto'
BOT_GSUTIL='/b/build/scripts/slave/gsutil'

cd ${NACLPORTS_ROOT}

# Don't do a full clean of naclports when we're testing the buildbot scripts
# locally.
if [ -z "${TEST_BUILDBOT:-}" ]; then
  make clean
fi

PACKAGES=$(make sdklibs_list)

# $1 - name of package
# $2 - arch to build for
# $3 - 'glibc' or 'newlib'
# $4 - 'Debug' or 'Release'
CustomBuildPackage() {
  export NACLPORTS_PREFIX=${OUT_BUNDLE_DIR}/build/$2_$3_$4
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
  if [ "$ARCH" != "arm" -a "$ARCH" != "pnacl" ]; then
    CustomBuildPackage $PACKAGE $ARCH glibc Release
    CustomBuildPackage $PACKAGE $ARCH glibc Debug
  fi
}

ARCH_LIST="i686 x86_64 arm pnacl"

# $1 - name of package
BuildPackageAll() {
  local PACKAGE=$1
  for ARCH in $ARCH_LIST; do
      BuildPackageArchAll $PACKAGE $ARCH
  done
  echo "naclports Install SUCCEEDED $PACKAGE"
}

MoveLibs() {
  for ARCH in $ARCH_LIST; do
    if [ "$ARCH" = "i686" ]; then
      ARCH_DIR=x86_32
    else
      ARCH_DIR=$ARCH
    fi

    if [ "$ARCH" = "arm" -o "$ARCH" = "pnacl" ]; then
      LIBC_VARIANTS="newlib"
    else
      LIBC_VARIANTS="newlib glibc"
    fi

    for LIBC in $LIBC_VARIANTS; do
      for CONFIG in Debug Release; do
        # Copy build results to destination directories.
        SRC_DIR=${OUT_BUNDLE_DIR}/build/${ARCH}_${LIBC}_${CONFIG}

        # copy includes
        mkdir -p ${OUT_PORTS_DIR}
        cp -d -r ${SRC_DIR}/include ${OUT_PORTS_DIR}

        # copy libs
        ARCH_LIB_DIR=${OUT_PORTS_DIR}/lib/${LIBC}_${ARCH_DIR}/${CONFIG}
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

if [ -z "${NACLPORTS_NO_UPLOAD:-}" ]; then
  echo "@@@BUILD_STEP create archive@@@"
  RunCmd tar -C ${OUT_BUNDLE_DIR} ${PEPPER_DIR} -jcf naclports.tar.bz2

  echo "@@@BUILD_STEP upload archive@@@"
  UPLOAD_PATH=nativeclient-mirror/naclports/${PEPPER_DIR}/${BUILDBOT_REVISION}
  if [ -e ${BOT_GSUTIL} ]; then
    GSUTIL=${BOT_GSUTIL}
  else
    GSUTIL=gsutil
  fi
  BOTO_CONFIG=${BOTO_CONFIG} RunCmd ${GSUTIL} cp -a public-read \
      naclports.tar.bz2 gs://${UPLOAD_PATH}/naclports.tar.bz2
  URL="https://commondatastorage.googleapis.com/${UPLOAD_PATH}/naclports.tar.bz2"
  echo "@@@STEP_LINK@download@${URL}@@@"
fi

echo "@@@BUILD_STEP summary@@@"
if [[ $RESULT != 0 ]] ; then
  echo "@@@STEP_FAILURE@@@"
  echo -e "$MESSAGES"
fi

exit $RESULT
