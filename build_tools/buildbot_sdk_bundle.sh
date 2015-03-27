#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# This script builds the packages that will be bundled with the NaCl SDK.

set -o errexit
set -o nounset

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
source ${SCRIPT_DIR}/buildbot_common.sh

NACLPORTS_ROOT="$(cd ${SCRIPT_DIR}/.. && pwd)"
OUT_DIR=${NACLPORTS_ROOT}/out
PACKAGE_DIR=${OUT_DIR}/packages

OUT_BUNDLE_DIR=${OUT_DIR}/sdk_bundle
OUT_PORTS_DIR=${OUT_BUNDLE_DIR}/${PEPPER_DIR}/ports

ARCH_LIST="i686 x86_64 arm pnacl"

CleanAllToolchains() {
  echo "@@@BUILD_STEP clean all@@@"
  for TC in pnacl newlib glibc; do
    CleanToolchain ${TC}
  done
}

cd ${NACLPORTS_ROOT}

# Don't do a full clean of naclports when we're testing the buildbot scripts
# locally.
if [ -z "${TEST_BUILDBOT:-}" ]; then
  CleanAllToolchains
fi

# Don't build lua with readline support. We don't want to include
# readline and ncurses in the SDK.
export LUA_NO_READLINE=1

PACKAGES=$(make sdklibs_list)

# Build a package in both Debug and Release configurations.
# $1 - name of package
# $2 - arch to build for
# $3 - toolchain ('glibc', 'newlib', 'pnacl')
CustomBuildPackage() {
  PACKAGE=$1
  export NACL_ARCH=$2
  export TOOLCHAIN=$3

  NACL_DEBUG=0 BuildPackage "${PACKAGE}" --no-deps
  NACL_DEBUG=1 BuildPackage "${PACKAGE}" --no-deps
}

# Build a package for all architectures.
# $1 - name of package
# $2 - arch to build for
BuildPackageArchAll() {
  local PACKAGE=$1
  local NACL_ARCH=$2
  if [ "${ARCH}" = "pnacl" ]; then
    CustomBuildPackage "${PACKAGE}" "${NACL_ARCH}" pnacl
  else
    CustomBuildPackage "${PACKAGE}" "${NACL_ARCH}" newlib
    if [ "${ARCH}" != "arm" ]; then
      CustomBuildPackage "${PACKAGE}" "${NACL_ARCH}" glibc
    fi
  fi
}

# $1 - name of package
BuildPackageAll() {
  local PACKAGE=$1
  echo "@@@BUILD_STEP ${PACKAGE}@@@"
  for ARCH in ${ARCH_LIST}; do
    BuildPackageArchAll "${PACKAGE}" "${ARCH}"
  done
  if [[ ${RESULT} != 0 ]] ; then
    echo "naclports Build FAILED ${PACKAGE}"
  else
    echo "naclports Build SUCCEEDED ${PACKAGE}"
  fi
}

MoveLibs() {
  local PACKAGE=$1
  for ARCH in ${ARCH_LIST}; do
    ARCH_PKG=${ARCH}
    ARCH_DIR=${ARCH}
    if [ "${ARCH}" = "i686" ]; then
      ARCH_DIR=x86_32
    fi
    if [ "${ARCH}" = "x86_64" ]; then
      ARCH_PKG="x86-64"
    fi

    if [ "${ARCH}" = "arm" -o "${ARCH}" = "pnacl" ]; then
      LIBC_VARIANTS="newlib"
    else
      LIBC_VARIANTS="newlib glibc"
    fi

    TMP_DIR=out/tmp

    for LIBC in ${LIBC_VARIANTS}; do
      for CONFIG in Debug Release; do
        PKG_SUFFIX="_${ARCH_PKG}"
        if [ "${ARCH}" != "pnacl" ]; then
          PKG_SUFFIX+="_${LIBC}"
        fi
        if [ "${CONFIG}" = "Debug" ]; then
          PKG_SUFFIX+="_debug"
        fi
        PKG_SUFFIX+=".tar.bz2"
        PKG_MATCH="${PACKAGE_DIR}/${PACKAGE}_*${PKG_SUFFIX}"
        PKG_FILE=$(shopt -s nullglob; echo ${PKG_MATCH})
        if [ -z "${PKG_FILE}" ]; then
          echo "Missing package file: ${PKG_MATCH}"
          exit 1
        fi
        rm -rf "${TMP_DIR}"
        mkdir "${TMP_DIR}"
        tar xf "${PKG_FILE}" -C "${TMP_DIR}"

        # Copy build results to destination directories.

        # copy includes
        mkdir -p "${OUT_PORTS_DIR}"
        SRC_DIR="${TMP_DIR}"/payload
        cp -d -r "${SRC_DIR}"/include "${OUT_PORTS_DIR}"

        # copy libs
        ARCH_LIB_DIR="${OUT_PORTS_DIR}/lib/${LIBC}_${ARCH_DIR}/${CONFIG}"
        mkdir -p "${ARCH_LIB_DIR}"
        for FILE in ${SRC_DIR}/lib/* ; do
          EXT="${FILE##*.}"
          if [[ ( -f "${FILE}" || -L "${FILE}" ) && "${EXT}" != "la" ]]; then
            cp -d -r "${FILE}" "${ARCH_LIB_DIR}"
          fi
        done
      done
    done
  done
}

for package in ${PACKAGES}; do
  BuildPackageAll "${package}"
done

echo "@@@BUILD_STEP copy to bundle@@@"
for package in ${PACKAGES}; do
  MoveLibs "${package}"
done

if [ -z "${NACLPORTS_NO_UPLOAD:-}" ]; then
  echo "@@@BUILD_STEP create archive@@@"
  RunCmd tar -C "${OUT_BUNDLE_DIR}" "${PEPPER_DIR}" -jcf naclports.tar.bz2

  echo "@@@BUILD_STEP upload archive@@@"
  RunCmd ${GSUTIL} cp -a public-read naclports.tar.bz2 gs://${UPLOAD_PATH}/
  URL="https://storage.googleapis.com/${UPLOAD_PATH}/naclports.tar.bz2"
  echo "@@@STEP_LINK@download@${URL}@@@"
fi

echo "@@@BUILD_STEP summary@@@"
if [[ ${RESULT} != 0 ]] ; then
  echo "@@@STEP_FAILURE@@@"
  echo -e "${MESSAGES}"
fi

exit "${RESULT}"
