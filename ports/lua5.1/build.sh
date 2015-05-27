# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}
EXECUTABLES="src/lua src/luac"

NACLPORTS_CPPFLAGS+=" -Dmain=nacl_main"
NACLPORTS_LDFLAGS+=" ${NACL_CLI_MAIN_LIB}"

if [ "${NACL_LIBC}" = "glibc" ]; then
  PLAT=nacl-glibc
else
  PLAT=nacl-newlib
fi


BuildStep() {
  LogExecute make PLAT=${PLAT} clean
  set -x
  make EXTRA_LIBS="${NACLPORTS_LDFLAGS}" EXTRA_CFLAGS="${NACLPORTS_CPPFLAGS}" \
       AR="${NACLAR} rcu" RANLIB="${NACLRANLIB}" \
       CC="${NACLCC}" PLAT=${PLAT} INSTALL_TOP="${DESTDIR}" -j${OS_JOBS}
  set +x
}


InstallStep() {
  LogExecute make "CC=${NACLCC}" "PLAT=generic" \
                  "INSTALL_TOP=${DESTDIR}/${PREFIX}" install
  ChangeDir src
  if [ "${NACL_ARCH}" = pnacl ]; then
    # Just do the x86-64 version for now.
    TranslateAndWriteLauncherScript lua x86-64 lua.x86-64.nexe lua.sh
    TranslateAndWriteLauncherScript luac x86-64 luac.x86-64.nexe luac.sh
  fi
}

PublishStep() {
  PublishByArchForDevEnv
}
