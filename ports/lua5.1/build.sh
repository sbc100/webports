#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}
EXECUTABLES="src/lua src/luac"

if [ "${NACL_GLIBC}" = "1" ]; then
  PLAT=nacl-glibc
else
  PLAT=nacl-newlib
fi
if [ "${LUA_NO_READLINE:-}" = "1" ]; then
  PLAT+=-basic
fi


BuildStep() {
  LogExecute make PLAT=${PLAT} clean
  set -x
  make AR="${NACLAR} rcu" RANLIB="${NACLRANLIB}" CC="${NACLCC}" PLAT=${PLAT} INSTALL_TOP="${NACLPORTS_PREFIX}" -j${OS_JOBS}
  set +x
}


InstallStep() {
  # TODO: side-by-side install
  LogExecute make "CC=${NACLCC}" "PLAT=generic" "INSTALL_TOP=${NACLPORTS_PREFIX}" install
  cd src
  if [ "${NACL_ARCH}" = pnacl ]; then
    # Just do the x86-64 version for now.
    TranslateAndWriteSelLdrScript lua x86-64 lua.x86-64.nexe lua.sh
    TranslateAndWriteSelLdrScript luac x86-64 luac.x86-64.nexe luac.sh
  fi
}
