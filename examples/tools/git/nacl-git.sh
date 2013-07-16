#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../../build_tools/common.sh

# Do a verbose build so we're confident it's hitting nacl's tools.
export MAKE_TARGETS="V=1"

export EXTRA_CONFIGURE_ARGS="--prefix= --exec-prefix="

CustomConfigureStep() {
  local SRC_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  ChangeDir ${SRC_DIR}
  autoconf

  export NACL_BUILD_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  export NACL_CONFIGURE_PATH=./configure
  DefaultConfigureStep

  # Git's build doesn't support building outside the source tree.
  # Do a clean to make rebuild after failure predictable.
  LogExecute make clean
}

CustomInstallStep() {
  local PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/tar"

  export INSTALL_TARGETS="DESTDIR=${ASSEMBLY_DIR} install"
  DefaultInstallStep
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  DefaultTranslateStep
  DefaultValidateStep
  CustomInstallStep
}

CustomPackageInstall

exit 0
