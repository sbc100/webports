# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# subversion's build system seem to have a bug with out-of-tree builds
# and parallel building that was causing occational flakes on the buildbots.
# The mkdir-init target appears to be required before any object file can be
# built but none of the object files seem to depend on this.
OS_JOBS=1

NACLPORTS_CPPFLAGS+=" -Dmain=nacl_main"

export LIBS+=" -Wl,--undefined=nacl_main ${NACL_CLI_MAIN_LIB} -lppapi_simple \
  -lnacl_io -lppapi -l${NACL_CXX_LIB}"

EXTRA_CONFIGURE_ARGS="--with-apr=${NACL_PREFIX}"
EXTRA_CONFIGURE_ARGS+=" --with-apr-util=${NACL_PREFIX}"
EXTRA_CONFIGURE_ARGS+=" --enable-all-static"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  export LIBS+=" -lglibc-compat"
fi

InstallStep() {
  return
}

PublishStep() {
  PublishByArchForDevEnv
}

