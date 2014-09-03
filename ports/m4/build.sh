# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export EXTRA_LIBS="${NACL_CLI_MAIN_LIB} -lppapi_simple -lnacl_spawn \
  -lnacl_io -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
fi

NACLPORTS_CPPFLAGS+=" -DGNULIB_defined_struct_sigaction"

PatchStep() {
  DefaultPatchStep
  # Touch documentation to prevent it from updating.
  touch ${SRC_DIR}/doc/*
}

InstallStep() {
  PublishByArchForDevEnv
}
