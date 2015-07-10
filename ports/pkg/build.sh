# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export LIBS+="${NACL_CLI_MAIN_LIB} -pthread -lresolv -ldl -lrt"
EXECUTABLES="src/pkg${NACL_EXEEXT} src/pkg-static${NACL_EXEEXT}"

NACLPORTS_CFLAGS+=" -Dmain=nacl_main"

# TODO: Remove this hack once glibc header bug is fixed
# Can also remove __unused -> _UNUSED_ patch in nacl.patch
# BUG=https://code.google.com/p/nativeclient/issues/detail?id=4207
# BUG=https://code.google.com/p/nativeclient/issues/detail?id=4208
PatchGlibcHeaders() {
  sed -i \
    "s/#ifdef __USE_FILE_OFFSET64\
/#if defined __USE_FILE_OFFSET64 \&\& !defined(__native_client__)/" \
    ${NACL_TOOLCHAIN_ROOT}/x86_64-nacl/include/fts.h
}

ConfigureStep() {
  if [ "${NACL_LIBC}" = "glibc" ]; then
    if ! grep -Eq "#ifdef __USE_FILE_OFFSET64 &&" \
      ${NACL_TOOLCHAIN_ROOT}/x86_64-nacl/include/fts.h ; then
      PatchGlibcHeaders
    fi
  fi
  ChangeDir ${SRC_DIR}
  ./autogen.sh
  PatchConfigure
  ChangeDir ${BUILD_DIR}
  DefaultConfigureStep
}

PublishStep() {
  PublishByArchForDevEnv
}
