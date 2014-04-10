#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}

BUILD_ARGS="\
  --build-dir=../${NACL_BUILD_SUBDIR} \
  --stagedir=../${NACL_BUILD_SUBDIR} \
  link=static"

# TODO(eugenis): build dynamic libraries, too
if [ "${NACL_LIBC}" = "glibc" ] ; then
  BUILD_ARGS+=" --without-python --without-signals --without-mpi"
  BUILD_ARGS+=" --without-context --without-coroutine"
else
  BUILD_ARGS+=" --with-date_time --with-program_options"
fi

ConfigureStep() {
  echo "using gcc : 4.4.3 : ${NACLCXX} ;" > tools/build/v2/user-config.jam
  LogExecute ./bootstrap.sh --prefix=${NACLPORTS_PREFIX}
}

BuildStep() {
  LogExecute ./b2 stage ${BUILD_ARGS}
}

InstallStep() {
  LogExecute ./b2 install ${BUILD_ARGS}
}
