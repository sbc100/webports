# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
fi

# TODO(eugenis): build dynamic libraries, too
BUILD_ARGS="
  target-os=unix
  --build-dir=../${NACL_BUILD_SUBDIR} \
  --stagedir=../${NACL_BUILD_SUBDIR} \
  link=static"

BUILD_ARGS+=" --without-python"
BUILD_ARGS+=" --without-signals"
BUILD_ARGS+=" --without-mpi"
BUILD_ARGS+=" --without-context"
BUILD_ARGS+=" --without-coroutine"

if [ "${NACL_LIBC}" = "newlib" ] ; then
  BUILD_ARGS+=" --without-locale"
fi

ConfigureStep() {
  echo "using gcc : 4.4.3 : ${NACLCXX} <compileflags>${NACLPORTS_CPPFLAGS};" \
      >> tools/build/v2/user-config.jam
  LogExecute ./bootstrap.sh --prefix=${NACL_PREFIX}
}

BuildStep() {
  LogExecute ./b2 stage -j ${OS_JOBS} ${BUILD_ARGS}
}

InstallStep() {
  LogExecute ./b2 install -d0 --prefix=${DESTDIR}/${PREFIX} ${BUILD_ARGS}
}
