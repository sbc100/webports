# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="src/pkg${NACL_EXEEXT}"
export LIBS+="-lbsd ${NACL_CLI_MAIN_LIB} -pthread"

EXTRA_CONFIGURE_ARGS+=" --prefix=/usr --exec-prefix=/usr"
NACLPORTS_CFLAGS+=" -Dmain=nacl_main"

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
  LogExecute mv ${DESTDIR}/usr ${DESTDIR}/${PREFIX}
  if [ "${NACL_SHARED}" = "0" ]; then
      LogExecute mv ${DESTDIR}/${PREFIX}/sbin/pkg-static${NACL_EXEEXT}\
         ${DESTDIR}/${PREFIX}/sbin/pkg${NACL_EXEEXT}
  fi
}

PublishStep() {
  PublishMultiArch src/pkg-static${NACL_EXEEXT} pkg
}
