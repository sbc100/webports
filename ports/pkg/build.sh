# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="src/pkg${NACL_EXEEXT}"
export LIBS+="-lbsd ${NACL_CLI_MAIN_LIB} -pthread"

NACLPORTS_CFLAGS+=" -Dmain=nacl_main"

# TODO: Remove this hack once glibc header bug is fixed
# Can also remove __unused -> _UNUSED_ patch in nacl.patch
# BUG=https://code.google.com/p/nativeclient/issues/detail?id=4207
# BUG=https://code.google.com/p/nativeclient/issues/detail?id=4208
PatchGlibcHeaders() {
  sed -i.bak \
    "s/#ifdef __USE_FILE_OFFSET64\
/#if defined __USE_FILE_OFFSET64 \&\& !defined(__native_client__)/" \
    ${NACL_TOOLCHAIN_ROOT}/x86_64-nacl/include/fts.h
}

if [ "${NACL_SHARED}" = "1" ]; then
  LIBS+=" -lresolv -ldl -lrt"
  EXECUTABLES+=" src/pkg-static${NACL_EXEEXT}"
  EXTRA_CONFIGURE_ARGS+=" --enable-shared=yes --with-staticonly=no"
  NACLPORTS_CPPFLAGS+=" -D_GNU_SOURCE"
else
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  LIBS+=" -lglibc-compat"
  EXTRA_CONFIGURE_ARGS+=" --enable-shared=no --with-staticonly=yes"
fi

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

BuildStep() {
  DefaultBuildStep
  if [ "${NACL_SHARED}" = "0" ]; then
    mv src/pkg-static${NACL_EXEEXT} src/pkg${NACL_EXEEXT}
  fi
}

InstallStep() {
  DefaultInstallStep
  if [ "${NACL_SHARED}" = "0" ]; then
      LogExecute mv ${DESTDIR}/${PREFIX}/sbin/pkg-static${NACL_EXEEXT}\
         ${DESTDIR}/${PREFIX}/sbin/pkg${NACL_EXEEXT}
  fi
}

PublishStep() {
  PublishByArchForDevEnv
  PublishMultiArch src/pkg-static${NACL_EXEEXT} pkg
}
