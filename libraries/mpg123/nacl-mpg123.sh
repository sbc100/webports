#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

source pkg_info
source ../../build_tools/common.sh

# TODO(binji): Use assembly
export EXTRA_CONFIGURE_ARGS="--disable-shared --enable-static \
    -with-cpu=generic_fpu"
export LDFLAGS="${LDFLAGS} -static"

CustomBuildStep() {
  Banner "Build ${PACKAGE_NAME}"

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/build-nacl/src/libmpg123
  echo "Directory: $(pwd)"
  LogExecute make clean
  LogExecute make -j${OS_JOBS}

  local tests="tests/seek_accuracy tests/seek_whence tests/text"

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/build-nacl/src
  echo "Directory: $(pwd)"
  LogExecute make clean
  LogExecute make -j${OS_JOBS} ${tests}
}

CustomInstallStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/build-nacl/src/libmpg123
  LogExecute make install

  DefaultTouchStep
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadBzipStep
  DefaultExtractBzipStep
  DefaultPatchStep
  DefaultConfigureStep
  CustomBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
