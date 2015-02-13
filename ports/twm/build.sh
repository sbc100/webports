# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

NACLPORTS_CPPFLAGS+=" -Dmain=nacl_main"

export LIBS+="\
  -lXext -lXmu -lSM -lICE -lXt -lX11 -lxcb -lXau \
  -Wl,--undefined=nacl_main ${NACL_CLI_MAIN_LIB} \
  -lppapi_simple -lnacl_io -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  export LIBS+=" -lglibc-compat"
fi

if [ "${TOOLCHAIN}" = "pnacl" ]; then
  NACLPORTS_CFLAGS+=" -Wno-return-type"
fi

BuildStep() {
  RC=deftwmrc.c
  rm -f ${RC}
  echo 'char *defTwmrc[] = {' >>${RC}
  sed -e '/^#/d' -e 's/"/\\"/g' -e 's/^/    "/' -e 's/$/",/' \
    ${SRC_DIR}/system.twmrc >>${RC}
  echo '    (char *) 0 };' >>${RC}

  flex ${SRC_DIR}/lex.l
  bison --defines=gram.h ${SRC_DIR}/gram.y
  SetupCrossEnvironment
  ${CC} ${CPPFLAGS} ${CFLAGS} -o twm ${SRC_DIR}/*.c *.c -I. -I${SRC_DIR} \
    ${LDFLAGS} ${LIBS}
}

InstallStep() {
  return
}

PublishStep() {
  PublishByArchForDevEnv
}
