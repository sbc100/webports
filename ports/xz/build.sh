# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export EXTRA_LIBS+="${NACL_CLI_MAIN_LIB} \
-lnacl_spawn -lppapi_simple -lnacl_io -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"

export LIBS+="-pthread -lnacl_io -l${NACL_CPP_LIB}"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  LIBS+=" -lglibc-compat"
fi

InstallStep() {
  export PUBLISH_CREATE_NMF_ARGS="-L ${DESTDIR_LIB}"

  DefaultInstallStep
  PublishByArchForDevEnv
}
