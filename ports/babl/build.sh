# Copyright (c) 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

ConfigureStep() {
  if [ "${NACL_LIBC}" = "newlib" ]; then
    NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  fi

  NACLPORTS_CPPFLAGS+=" -Dmain=nacl_main"
  NACLPORTS_LDFLAGS+=" ${NACL_CLI_MAIN_LIB}"

  DefaultConfigureStep
}
