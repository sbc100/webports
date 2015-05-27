# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXTRA_CONFIGURE_ARGS+=" --datarootdir=/share"

NACLPORTS_CPPFLAGS+=" -Dmain=nacl_main"
export LIBS="-lX11 -lxcb -lXau ${NACL_CLI_MAIN_LIB}"

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
