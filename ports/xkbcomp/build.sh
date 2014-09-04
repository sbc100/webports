# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXTRA_CONFIGURE_ARGS+=" --datarootdir=/mnt/html5/share"

NACLPORTS_CPPFLAGS+=" -Dmain=nacl_main"
export LIBS+=" -Wl,--undefined=nacl_main ${NACL_CLI_MAIN_LIB} \
  -lX11 -lxcb -lXau \
  -lppapi_simple -lnacl_spawn \
  -lnacl_io -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  export LIBS+=" -lglibc-compat"
fi

InstallStep() {
  PublishByArchForDevEnv
}
