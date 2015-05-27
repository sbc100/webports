# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}
EXECUTABLES="src/lua${NACL_EXEEXT} src/luac${NACL_EXEEXT}"

NACLPORTS_CPPFLAGS+=" -Dmain=nacl_main"
NACLPORTS_LDFLAGS+=" ${NACL_CLI_MAIN_LIB}"

if [ "${NACL_LIBC}" = "glibc" ]; then
  PLAT=nacl-glibc
else
  PLAT=nacl-newlib
fi

# The 5.2.2 tests are the most recent and are still recommended for 5.2.4
TEST_FILE=lua-5.2.2-tests.tar.gz
TEST_URL=http://www.lua.org/tests/${TEST_FILE}
TEST_SHA1=89abce5ab3080783dec9785c8fe5da6d4896de05

DownloadStep() {
  if ! CheckHash ${NACL_PACKAGES_CACHE}/${TEST_FILE} ${TEST_SHA1}; then
    Fetch ${TEST_URL} ${NACL_PACKAGES_CACHE}/${TEST_FILE}
    if ! CheckHash ${NACL_PACKAGES_CACHE}/${TEST_FILE} ${TEST_SHA1} ; then
       Banner "${TEST_FILE} failed checksum!"
       exit -1
    fi
  fi
}

BuildStep() {
  LogExecute make PLAT=${PLAT} clean
  set -x
  make MYLDFLAGS="${NACLPORTS_LDFLAGS}" MYCFLAGS="${NACLPORTS_CPPFLAGS}" \
    AR="${NACLAR} rcu" RANLIB="${NACLRANLIB}" CC="${NACLCC}" PLAT=${PLAT} \
    EXEEXT=${NACL_EXEEXT} -j${OS_JOBS}
  set +x
}

TestStep() {
  if [ "${NACL_ARCH}" = pnacl ]; then
    ChangeDir src
    # Just do the x86-64 version for now.
    TranslateAndWriteLauncherScript lua.pexe x86-64 lua.x86-64.nexe lua
    TranslateAndWriteLauncherScript luac.pexe x86-64 luac.x86-64.nexe luac
    ChangeDir ..
  fi

  # First, run the 'make test' target.  This currently just runs
  # lua -v.
  LogExecute make PLAT=${PLAT} test

  # Second, run the lua unittests. See: http://www.lua.org/tests/
  if [ -d lua-5.2.2-tests ]; then
    Remove lua-5.2.2-tests
  fi
  LogExecute tar zxf ${NACL_PACKAGES_CACHE}/${TEST_FILE}
  ChangeDir lua-5.2.2-tests
  LogExecute patch -p1 < ${START_DIR}/lua_tests.patch
  LogExecute ../src/lua -e"_U=true" all.lua
}

InstallStep() {
  LogExecute make PLAT=${PLAT} EXEEXT=${NACL_EXEEXT} \
                  INSTALL_TOP=${DESTDIR}/${PREFIX} install
}

PublishStep() {
  PublishByArchForDevEnv
}
