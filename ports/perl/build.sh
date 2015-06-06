# Copyright (c) 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# falling back to cc for generating build time artifacts
export BUILD_CC=cc
export BUILD_LD=cc
# use -Wno-return-type to suppress return-type errors encountered
# with pnacl, arm's clang-newlib
NACLPORTS_CFLAGS+=" -Dmain=nacl_main -Wno-return-type"
BUILD_DIR=${SRC_DIR}
EXECUTABLES="microperl"
export NACLPORTS_LDFLAGS+=" ${NACL_CLI_MAIN_LIB} -lppapi_simple -lnacl_io \
  -lppapi -l${NACL_CXX_LIB}"

BuildStep() {
  # clean up previous executables
  LogExecute make -j${OS_JOBS} -f Makefile.micro clean
  # microperl build from Makefile.micro
  LogExecute make -j${OS_JOBS} -f Makefile.micro CC="${NACLCC}" \
    CCFLAGS=" -c -DHAS_DUP2 -DPERL_MICRO ${NACLPORTS_CFLAGS}" \
    LDFLAGS="${NACLPORTS_LDFLAGS}"
}

InstallStep() {
  # microperl doesn't require make install
  return
}

PublishStep() {
  PublishByArchForDevEnv
}
