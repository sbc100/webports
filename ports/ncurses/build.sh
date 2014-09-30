# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="progs/clear${NACL_EXEEXT}"

EXTRA_CONFIGURE_ARGS+=" --disable-database"
EXTRA_CONFIGURE_ARGS+=" --with-fallbacks=xterm-256color,vt100"
EXTRA_CONFIGURE_ARGS+=" --disable-termcap"
# Without this ncurses headers will be installed include/ncurses
EXTRA_CONFIGURE_ARGS+=" --enable-overwrite"
EXTRA_CONFIGURE_ARGS+=" --without-ada"

if [ "${NACL_SHARED}" = 1 ]; then
  EXTRA_CONFIGURE_ARGS+=" --with-shared"
fi

if [ "${NACL_ARCH}" = "pnacl" ] ; then
  EXTRA_CONFIGURE_ARGS+=" --without-cxx-binding"
fi

ConfigureStep() {
  export cf_cv_ar_flags=${NACL_ARFLAGS}
  NACL_ARFLAGS=""
  if [ "${NACL_LIBC}" = "newlib" ]; then
    # Changing NACLCC rather than CFLAGS as otherwise the configure script
    # fails to detect termios and tries to use gtty.
    NACLCC+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
    export LIBS="-lglibc-compat"
  fi

  DefaultConfigureStep
  # Glibc inaccurately reports having sigvec.
  # Change the define
  sed -i.bak 's/HAVE_SIGVEC 1/HAVE_SIGVEC 0/' include/ncurses_cfg.h
}

InstallStep() {
  DefaultInstallStep
  cd ${DESTDIR_LIB}
  ln -sf libncurses.a libtermcap.a
  cd -
}
