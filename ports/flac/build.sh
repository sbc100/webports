#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


ConfigureStep() {
  if [ "${NACL_LIBC}" = "newlib" ]; then
    export LIBS="-lglibc-compat"
  fi
  EXTRA_CONFIGURE_ARGS+=" --disable-oggtest"
  EXTRA_CONFIGURE_ARGS+=" --disable-xmms-plugin"
  EXTRA_CONFIGURE_ARGS+=" --without-metaflac-test-files"
  DefaultConfigureStep
  PostConfigureStep
}


PostConfigureStep() {
  # satisfy random, srandom
  echo "/* pull features.h that has __GLIBC__ */" >> config.h
  echo "#include <stdlib.h>" >> config.h
  echo "#ifndef __GLIBC__" >> config.h
  echo "# define random() rand()" >> config.h
  echo "# define srandom(x) srand(x)" >> config.h
  echo "#endif" >> config.h
}


InstallStep() {
  # assumes pwd has makefile
  LogExecute make install-exec DESTDIR=${DESTDIR}
  ChangeDir include
  LogExecute make install DESTDIR=${DESTDIR}
}
