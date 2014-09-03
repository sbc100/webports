# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
fi

ConfigureStep() {
  export CROSS_COMPILE=true
  export CONFIG_SITE=${START_DIR}/config.site
  EXTRA_CONFIGURE_ARGS="--disable-shared --disable-linux-lfs --disable-largefile"
  EXTRA_CONFIGURE_ARGS+=" --disable-largefile"
  DefaultConfigureStep
  LogExecute cp ${START_DIR}/H5lib_settings.c ${SRC_DIR}/src/
  LogExecute cp ${START_DIR}/H5Tinit.c ${SRC_DIR}/src/
}
