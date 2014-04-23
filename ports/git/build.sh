#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export EXTRA_LIBS=\
"-lppapi -lppapi_cpp -lppapi_simple -lcli_main -lnacl_io -lnacl_spawn"

# Do a verbose build so we're confident it's hitting nacl's tools.
MAKE_TARGETS="V=1"
BUILD_DIR=${SRC_DIR}
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

  if [ "${NACL_LIBC}" = "newlib" ]; then
    NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
    NACLPORTS_LDFLAGS+=" -lglibc-compat"
  fi

  if [ "${NACL_LIBC}" = "glibc" ]; then
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
  for name in $(cat ${START_DIR}/git_binaries.txt); do
    cp ${name} ${PUBLISH_DIR}/${name}_${NACL_ARCH}${NACL_EXEEXT}

    pushd ${PUBLISH_DIR}
    LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
        ${PUBLISH_DIR}/${name}_*${NACL_EXEEXT} \
        -s . \
        -o ${name}.nmf
    popd
  done
}
