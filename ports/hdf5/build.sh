#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

if [ "${NACL_GLIBC}" != "1" ]; then
  export NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS} -I${NACLPORTS_INCLUDE}/glibc-compat"
  export NACLPORTS_CXXFLAGS="${NACLPORTS_CXXFLAGS} -I${NACLPORTS_INCLUDE}/glibc-compat"
fi

ConfigureStep() {
  export CROSS_COMPILE=true
  export CONFIG_SITE=${START_DIR}/config.site
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  EXTRA_CONFIGURE_ARGS="--disable-shared --disable-linux-lfs"
  EXTRA_CONFIGURE_ARGS+=" --disable-largefile"
  DefaultConfigureStep
  LogExecute cp ${START_DIR}/H5lib_settings.c ${SRC_DIR}/src/
  LogExecute cp ${START_DIR}/H5Tinit.c ${SRC_DIR}/src/
}
