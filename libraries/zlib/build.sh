#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh


ConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  LogExecute rm -f libz.*
  # TODO: side-by-side install
  local CONFIGURE_ARGS="--prefix=${NACLPORTS_PREFIX}"
  local CFLAGS="-Dunlink=puts"
  if [ "${NACL_GLIBC}" = "1" -a $# -gt 0 ]; then
      CONFIGURE_ARGS="${CONFIGURE_ARGS} --shared"
      CFLAGS="${CFLAGS} -fPIC"
  fi
  CC=${NACLCC} AR="${NACLAR} -r" RANLIB=${NACLRANLIB} CFLAGS="${CFLAGS}" \
     LogExecute ./configure ${CONFIGURE_ARGS}
  export MAKEFLAGS="EXE=${NACL_EXEEXT}"
  EXECUTABLES="minigzip${NACL_EXEEXT} example${NACL_EXEEXT}"
}

RunMinigzip() {
  export LD_LIBRARY_PATH=.
  if echo "hello world" | ./minigzip | ./minigzip -d; then
    echo '  *** minigzip test OK ***' ; \
      else
    echo '  *** minigzip test FAILED ***' ; \
      exit 1
  fi
  unset LD_LIBRARY_PATH
}

RunExample() {
  export LD_LIBRARY_PATH=.
  # This second test does not yet work on nacl (gzopen fails)
  #if ./example; then \
    #echo '  *** zlib test OK ***'; \
  #else \
    #echo '  *** zlib test FAILED ***'; \
    #exit 1
  #fi
  unset LD_LIBRARY_PATH
}

TestStep() {
  if [ "${SKIP_SEL_LDR_TESTS}" = "1" ]; then
    return
  fi

  if [ "${NACL_GLIBC}" = "1" ]; then
    # Tests do not currently run on GLIBC due to fdopen() not working
    # TODO(sbc): Remove this once glibc is fixed:
    # https://code.google.com/p/nativeclient/issues/detail?id=3362
    return
  fi

  if [ $NACL_ARCH = "pnacl" ]; then
    local minigzip_pexe="minigzip${NACL_EXEEXT}"
    local example_pexe="example${NACL_EXEEXT}"
    local minigzip_script="minigzip"
    local example_script="example"
    TranslateAndWriteSelLdrScript ${minigzip_pexe} x86-32 \
      minigzip.x86-32.nexe ${minigzip_script}
    RunMinigzip
    TranslateAndWriteSelLdrScript ${minigzip_pexe} x86-64 \
      minigzip.x86-64.nexe ${minigzip_script}
    RunMinigzip
    TranslateAndWriteSelLdrScript ${example_pexe} x86-32 \
      example.x86-32.nexe ${example_script}
    RunExample
    TranslateAndWriteSelLdrScript ${example_pexe} x86-64 \
      example.x86-64.nexe ${example_script}
    RunExample
  else
    WriteSelLdrScript minigzip minigzip.nexe
    RunMinigzip
    WriteSelLdrScript example example.nexe
    RunExample
  fi
}


PackageInstall() {
  PreInstallStep
  DownloadStep
  ExtractStep
  PatchStep
  ConfigureStep
  BuildStep
  ValidateStep
  TestStep
  DefaultInstallStep
  if [ "${NACL_GLIBC}" = "1" ]; then
    ConfigureStep shared
    BuildStep
    Validate libz.so.1
    ValidateStep
    TestStep
    InstallStep
  fi
}


PackageInstall
exit 0
