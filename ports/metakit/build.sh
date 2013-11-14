#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

source pkg_info
source ../../build_tools/common.sh

export NACL_CONFIGURE_PATH=\
${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/unix/configure

if [ ${NACL_GLIBC} != "1" ]; then
  export EXTRA_CONFIGURE_ARGS="--disable-shared"
  export MAKE_TARGETS="libmk4.a"
else
  export MAKE_TARGETS="libmk4.so libmk4.a"
fi

AutoconfStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  pushd unix
  autoconf
  popd
}

ConfigureStep() {
  AutoconfStep
  DefaultConfigureStep
}

DefaultPackageInstall
exit 0
