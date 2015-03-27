#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

RESULT=0
MESSAGES=

# SCRIPT_DIR must be defined by the including script
readonly BASE_DIR="$(dirname ${SCRIPT_DIR})"
readonly PYTHON=${SCRIPT_DIR}/python_wrapper
cd ${BASE_DIR}

UPLOAD_PATH=naclports/builds/${PEPPER_DIR}/
if [ -d .git ]; then
  UPLOAD_PATH+=$(git describe)
else
  UPLOAD_PATH+=${BUILDBOT_GOT_REVISION}
fi

BuildSuccess() {
  echo "naclports: Build SUCCEEDED $1 (${NACL_ARCH}/${TOOLCHAIN})"
}

BuildFailure() {
  MESSAGE="naclports: Build FAILED for $1 (${NACL_ARCH}/${TOOLCHAIN})"
  echo ${MESSAGE}
  echo "@@@STEP_FAILURE@@@"
  MESSAGES="${MESSAGES}\n${MESSAGE}"
  RESULT=1
  if [ "${TEST_BUILDBOT:-}" = "1" ]; then
    exit 1
  fi
}

RunCmd() {
  echo "$@"
  "$@"
}

NACLPORTS_ARGS="-v --ignore-disabled --from-source"
export FORCE_MIRROR="yes"

#
# Build a single package for a single architecture
# $1 - Name of package to build
#
BuildPackage() {
  PACKAGE=$1
  shift
  if RunCmd bin/naclports ${NACLPORTS_ARGS} "$@" install ${PACKAGE}; then
    BuildSuccess ${PACKAGE}
  else
    BuildFailure ${PACKAGE}
  fi
}

InstallPackageMultiArch() {
  echo "@@@BUILD_STEP ${TOOLCHAIN} $1@@@"

  if [ "${TOOLCHAIN}" = "pnacl" ]; then
    arch_list="pnacl"
  elif [ "${TOOLCHAIN}" = "emscripten" ]; then
    arch_list="emscripten"
  elif [ "${TOOLCHAIN}" = "bionic" ]; then
    arch_list="arm"
  elif [ "${TOOLCHAIN}" = "glibc" ]; then
    arch_list="i686 x86_64"
  else
    arch_list="i686 x86_64 arm"
  fi

  for NACL_ARCH in ${arch_list}; do
    export NACL_ARCH
    if ! RunCmd bin/naclports uninstall --all ; then
      BuildFailure $1
      return
    fi
    if ! RunCmd bin/naclports ${NACLPORTS_ARGS} install $1 ; then
      # Early exit if one of the architecures fails. This mean the
      # failure is always at the end of the build step.
      BuildFailure $1
      return
    fi
  done
  export NACL_ARCH=all
  BuildSuccess $1
}

CleanToolchain() {
  # Don't use TOOLCHAIN and NACL_ARCH here as we don't want to
  # clobber the globals.
  TC=$1

  if [ "${TC}" = "pnacl" ]; then
    arch_list="pnacl"
  elif [ "${TC}" = "emscripten" ]; then
    arch_list="emscripten"
  elif [ "${TC}" = "bionic" ]; then
    arch_list="arm"
  elif [ "${TC}" = "glibc" ]; then
    arch_list="i686 x86_64"
  else
    arch_list="i686 x86_64 arm"
  fi

  for ARCH in ${arch_list}; do
    if ! TOOLCHAIN=${TC} NACL_ARCH=${ARCH} RunCmd \
        bin/naclports clean --all; then
      TOOLCHAIN=${TC} NACL_ARCH=${ARCH} BuildFailure clean
    fi
  done
}

CleanCurrentToolchain() {
  echo "@@@BUILD_STEP clean@@@"
  CleanToolchain ${TOOLCHAIN}
}

