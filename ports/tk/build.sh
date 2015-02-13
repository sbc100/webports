# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

NACL_CONFIGURE_PATH=${SRC_DIR}/unix/configure

NACLPORTS_CPPFLAGS+=" -Dmain=nacl_main"
export LIBS+=" -lX11 -lxcb -lXau \
  -Wl,--undefined=nacl_main ${NACL_CLI_MAIN_LIB} \
  -lppapi_simple -lnacl_io -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"

EXTRA_CONFIGURE_ARGS+=" --with-tcl=${NACLPORTS_LIBDIR}"

if [ "${NACL_ARCH}" = "pnacl" ]; then
  EXTRA_CONFIGURE_ARGS+=" --disable-load"
fi

# Disable fallbacks for broken libc's that kick in for
# cross-compiles since autoconf can't run target binaries.
# The fallbacks seem to be non-general.
export tcl_cv_strtod_buggy=ok

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  LIBS+=" -lglibc-compat"
fi

# Ideally we would only add this flag for newlib builds but
# linking of the shared library currently fails because it
# tries to link libppapi_stub.a which is not built with -fPIC.
EXTRA_CONFIGURE_ARGS+=" --disable-shared"

PublishStep() {
  PublishByArchForDevEnv
}
