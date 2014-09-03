# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}
EXECUTABLES="src/lua${NACL_EXEEXT} src/luac${NACL_EXEEXT}"

if [ "${NACL_LIBC}" = "glibc" ]; then
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
  make AR="${NACLAR} rcu" RANLIB="${NACLRANLIB}" CC="${NACLCC}" PLAT=${PLAT} EXEEXT=${NACL_EXEEXT} -j${OS_JOBS}
  set +x
}


TestStep() {
  pushd src
  if [ "${NACL_ARCH}" = pnacl ]; then
    # Just do the x86-64 version for now.
    TranslateAndWriteSelLdrScript lua.pexe x86-64 lua.x86-64.nexe lua
    TranslateAndWriteSelLdrScript luac.pexe x86-64 luac.x86-64.nexe luac
  fi
  popd

  if [ "${NACL_ARCH}" != "arm" ]; then
    LogExecute make PLAT=${PLAT} test
  fi
}


InstallStep() {
  LogExecute make PLAT=${PLAT} EXEEXT=${NACL_EXEEXT} \
                  INSTALL_TOP=${DESTDIR}/${PREFIX} install
}
