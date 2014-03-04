#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Do a verbose build so we're confident it's hitting nacl's tools.
MAKE_TARGETS="V=1"
EXTRA_CONFIGURE_ARGS="--prefix= --exec-prefix="
BUILD_DIR=${SRC_DIR}
NACL_CONFIGURE_PATH=./configure
export CROSS_COMPILE=1

if [ ${OS_NAME} = "Darwin" ]; then
  # gettext (msgfmt) doesn't exist on darwin by default.  homebrew installs
  # it to /usr/local/opt/gettext, and we need it to be in the PATH when
  # building git
  export PATH=${PATH}:/usr/local/opt/gettext/bin
fi

ConfigureStep() {
  ChangeDir ${SRC_DIR}
  autoconf

  if [[ "${NACL_GLIBC}" != 1 ]]; then
    readonly GLIBC_COMPAT=${NACLPORTS_INCLUDE}/glibc-compat
    NACLPORTS_CPPFLAGS+=" -I${GLIBC_COMPAT}"
    NACLPORTS_LDFLAGS+=" -lglibc-compat"
  else
    # Because libcrypto.a needs dlsym we need to add this explicitly.
    # This is not normally needed when libcyrpto is a shared library.
    NACLPORTS_LDFLAGS+=" -ldl"
  fi

  DefaultConfigureStep
}

BuildStep() {
  SetupCrossEnvironment
  ChangeDir ${SRC_DIR}
  # Git's build doesn't support building outside the source tree.
  # Do a clean to make rebuild after failure predictable.
  LogExecute make clean
  DefaultBuildStep
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/tar"

  export INSTALL_TARGETS="DESTDIR=${ASSEMBLY_DIR} install"
  DefaultInstallStep
}
