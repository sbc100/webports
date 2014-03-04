#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BuildStep() {
  # gdb configures its submodules at build time so we need to setup
  # the cross enrionment here.  Without this CPPFLAGS doesn't get set
  # in gdb/Makefile.
  SetupCrossEnvironment
  DefaultBuildStep
}

InstallStep() {
  DefaultInstallStep

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
  SetupCrossEnvironment

  cp ${START_DIR}/gdb_pepper.c ${SRC_DIR}/gdb
  echo "CPPFLAGS=${CPPFLAGS}"
  echo "CFLAGS=${CFLAGS}"
  LogExecute ../configure --with-curses --with-expat --with-system-readline \
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
