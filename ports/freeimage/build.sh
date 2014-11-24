# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}

ConfigureStep() {
  return
}

BuildStep() {
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export CFLAGS="${NACLPORTS_CPPFLAGS} ${NACLPORTS_CFLAGS}"
  export CXXFLAGS="${NACLPORTS_CPPFLAGS} ${NACLPORTS_CXXFLAGS}"
  export PATH=${NACL_BIN_PATH}:${PATH}

  # assumes pwd has makefile
  LogExecute make -f Makefile.nacl clean
  LogExecute make -f Makefile.nacl -j${OS_JOBS}
}

InstallStep() {
  export INCDIR=${DESTDIR_INCLUDE}
  export INSTALLDIR=${DESTDIR_LIB}
  LogExecute make -f Makefile.nacl install
}
