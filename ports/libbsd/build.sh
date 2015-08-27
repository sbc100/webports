# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXTRA_CONFIGURE_ARGS="--disable-largefile"

export getline=getline

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat -std=gnu99"
  NACLPORTS_LDFLAGS+=" -lglibc-compat"
  export getline=__getline
fi

BuildHost() {
  HOST_BUILD_DIR=${WORK_DIR}/build_host
  HOST_INSTALL_DIR=${WORK_DIR}/install_host
  if [ ! -d ${HOST_INSTALL_DIR} ]; then
    Banner "Build host version"
    MakeDir ${HOST_BUILD_DIR}
    ChangeDir ${HOST_BUILD_DIR}
    LogExecute ${SRC_DIR}/configure
    LogExecute make -j${OS_JOBS}
    LogExecute make install DESTDIR=${HOST_INSTALL_DIR}
    cd -
  fi
}

BuildStep() {
  (unset getline && BuildHost)
  DefaultBuildStep
}
