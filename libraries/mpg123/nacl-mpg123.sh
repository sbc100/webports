#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

# TODO(binji): Use assembly
export EXTRA_CONFIGURE_ARGS="--enable-static -with-cpu=generic_fpu"

if [ "${NACL_GLIBC}" != "1" ]; then
  # Disable network support for newlib builds.
  # TODO(sbc): remove this once network syscalls land in libnacl
  EXTRA_CONFIGURE_ARGS+=" --enable-network=no"
fi

export LDFLAGS="${LDFLAGS} -static"

CustomBuildStep() {
  Banner "Build ${PACKAGE_NAME}"

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/${NACL_BUILD_SUBDIR}/src/libmpg123
  echo "Directory: $(pwd)"
  LogExecute make clean
  LogExecute make -j${OS_JOBS}

  Banner "Build Tests"
  local tests="tests/seek_accuracy${NACL_EXEEXT} tests/seek_whence${NACL_EXEEXT} tests/text${NACL_EXEEXT}"

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/${NACL_BUILD_SUBDIR}/src
  echo "Directory: $(pwd)"
  LogExecute make clean
  LogExecute make -j${OS_JOBS} ${tests}
}

CustomInstallStep() {
  Banner "Install"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/${NACL_BUILD_SUBDIR}/src/libmpg123
  LogExecute make install
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  DefaultConfigureStep
  CustomBuildStep
  CustomInstallStep
}

CustomPackageInstall
exit 0
