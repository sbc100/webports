# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

ConfigureStep() {
  if [ "${NACL_LIBC}" = "newlib" ]; then
    NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  fi

  export LIBS+=" -l${NACL_CPP_LIB}"

  # Grep fails to build NDEBUG defined
  # ib/chdir-long.c:62: error: unused variable 'close_fail'
  NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS/-DNDEBUG/}"
  DefaultConfigureStep
}

PublishStep() {
  PublishByArchForDevEnv
}
