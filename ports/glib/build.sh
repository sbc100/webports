# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="
  gio/gapplication${NACL_EXEEXT}
  glib/gtester${NACL_EXEEXT}
  gobject/gobject-query${NACL_EXEEXT}
"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
fi

ConfigureStep() {
  SetupCrossEnvironment
  if [ "${NACL_LIBC}" = "newlib" ]; then
    export LIBS+=" -lglibc-compat"
  fi

  export glib_cv_stack_grows=no
  export glib_cv_uscore=no
  export ac_cv_func_issetugid=no
  export ac_cv_func_posix_getpwuid_r=yes
  export ac_cv_func_posix_getgrgid_r=yes

  LogExecute ${SRC_DIR}/configure \
    --host=nacl \
    --prefix=${PREFIX} \
    --disable-libelf \
    --${NACL_OPTION}-mmx \
    --${NACL_OPTION}-sse \
    --${NACL_OPTION}-sse2 \
    --${NACL_OPTION}-asm
}
