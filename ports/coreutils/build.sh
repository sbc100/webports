#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export EXTRA_LIBS="${NACL_CLI_MAIN_LIB} -lppapi_simple \
  -lnacl_io -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"
CONFIG_SUB=config/config.sub

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  export EXTRA_LIBS+=" -lglibc-compat"
fi


BuildStep() {
  # Disable all assembly code by specifying none-none-none.
  DefaultBuildStep --target=none-none-none
}

InstallStep() {
  PublishByArchForDevEnv
}
