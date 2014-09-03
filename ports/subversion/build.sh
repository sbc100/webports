# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

NACLPORTS_CPPFLAGS+=" -Dmain=nacl_main"

export LIBS+=" -Wl,--undefined=nacl_main ${NACL_CLI_MAIN_LIB} -lppapi_simple \
  -lnacl_io -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"

EXTRA_CONFIGURE_ARGS="--with-apr=${NACL_PREFIX}"
EXTRA_CONFIGURE_ARGS+=" --with-apr-util=${NACL_PREFIX}"
EXTRA_CONFIGURE_ARGS+=" --enable-all-static"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  export LIBS+=" -lglibc-compat"
fi

InstallStep() {
  PublishByArchForDevEnv
}

