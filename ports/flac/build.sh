#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh


ConfigureStep() {
  if [ "${NACL_GLIBC}" != 1 ]; then
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
  make install-exec
  (cd include; make install)
}


PackageInstall
exit 0
