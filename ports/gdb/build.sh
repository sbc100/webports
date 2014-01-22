#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BuildStep() {
  make all
}

InstallStep() {
  make install

  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/gdb"
  MakeDir ${ASSEMBLY_DIR}
  LogExecute cp gdb/gdb.nexe \
      ${ASSEMBLY_DIR}/gdb_${NACL_ARCH}${NACL_EXEEXT}

  pushd ${ASSEMBLY_DIR}
  python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      gdb_*${NACL_EXEEXT} \
      -s . \
      -o gdb.nmf
  LogExecute python ${TOOLS_DIR}/create_term.py gdb.nmf
  popd

  InstallNaClTerm ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/background.js ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
}

ConfigureStep() {
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export CFLAGS=${NACLPORTS_CFLAGS}
  export CXXFLAGS=${NACLPORTS_CXXFLAGS}
  export LDFLAGS=${NACLPORTS_LDFLAGS}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export PATH=${NACL_BIN_PATH}:${PATH};
  export NACLPORTS_INCLUDE

  MakeDir ${BUILD_DIR}
  ChangeDir ${BUILD_DIR}

  cp ${START_DIR}/gdb_pepper.cc ${SRC_DIR}/gdb
  ../configure --with-curses --with-expat --with-system-readline \
      --disable-libmcheck \
      --prefix=${NACLPORTS_PREFIX} \
      --exec-prefix=${NACLPORTS_PREFIX} \
      --host=${NACL_CROSS_PREFIX} \
      --libdir=${NACLPORTS_LIBDIR}

  # If the .info files don't exist, "make all" will try to recreate it with the
  # "makeinfo" tool, which isn't normally installed.
  # Just copy the ones from the repo to the build directory.
  mkdir -p ${BUILD_DIR}/{gdb,bfd}/doc
  pushd ${SRC_DIR}
  find gdb bfd -name '*.info' -exec cp {} ${BUILD_DIR}/{} \;
  popd
}
