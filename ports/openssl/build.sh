#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}
INSTALL_TARGETS="install INSTALL_PREFIX=${DESTDIR}"

ConfigureStep() {
  if [ "${NACL_SHARED}" = "1" ] ; then
    local EXTRA_ARGS="shared"
  else
    local EXTRA_ARGS="no-dso"
  fi

  if [ "${NACL_LIBC}" = "newlib" ] ; then
    EXTRA_ARGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
    # The default from MACHINE=i686 is linux-elf, which links things
    # with -ldl. However, newlib does not have -ldl. In that case,
    # make a fake machine where the build rule does not use -ldl.
    local machine="le32newlib"
  else
    local machine="i686"
  fi

  MACHINE=${machine} CC=${NACLCC} AR=${NACLAR} RANLIB=${NACLRANLIB} \
    LogExecute ./config \
    --prefix=${PREFIX} no-asm no-hw no-krb5 ${EXTRA_ARGS} -D_GNU_SOURCE

  HackStepForNewlib
}


HackStepForNewlib() {
  if [ "${NACL_SHARED}" = "1" ]; then
    git checkout apps/Makefile
    git checkout test/Makefile
    return
  fi

  # apps/Makefile links programs that require socket(), etc.
  # Stub it out until we link against nacl_io or something.
  echo "all clean install: " > apps/Makefile
  # test/Makefile is similar -- stub out, but keep the original for testing.
  git checkout test/Makefile
  mv test/Makefile test/Makefile.orig
  echo "all clean install: " > test/Makefile
}


BuildStep() {
  LogExecute make clean
  # The openssl build can fail when build with -jN.
  # TODO(sbc): Add -j${OS_JOBS} to this build if/when openssl is upgraded
  # to a version that supports parallel make.
  LogExecute make build_libs
}


InstallStep() {
  DefaultInstallStep
  # openssl (for some reason) installs shared libraries with 555 (i.e.
  # not writable.  This causes issues when create_nmf copies the libraries
  # and then tries to overwrite them later.
  if [ "${NACL_SHARED}" = "1" ] ; then
    LogExecute chmod 644 ${DESTDIR_LIB}/libssl.so.*
    LogExecute chmod 644 ${DESTDIR_LIB}/libcrypto.so.*
  fi
}


TestStep() {
  echo "Running OpenSSL TestStep"
  # TODO(jvoung): Integrate better with "make test".
  # We'd need to make util/shlib_wrap.sh run the sel_ldr scripts instead
  # of trying to run the nexes directly.
  local all_tests="bntest ectest ecdsatest ecdhtest exptest \
ideatest shatest sha1test sha256t sha512t mdc2test rmdtest md2test md4test \
md5test hmactest wp_test rc2test rc4test rc5test bftest casttest \
destest randtest dhtest dsatest ssltest rsa_test enginetest igetest \
jpaketest srptest asn1test"
  local passing_tests="${all_tests}"
  ChangeDir test
  export SEL_LDR_LIB_PATH=$PWD/..
  # Newlib can't build ssltest -- requires socket()
  # md2test, rc5test, jpaketest just segfaults w/ nacl-gcc-newlib and pnacl.
  if [ "${NACL_LIBC}" = "newlib" ]; then
    local broken_tests="md2test rc5test ssltest jpaketest"
    for to_filter in ${broken_tests}; do
      passing_tests=$(echo ${passing_tests} | sed "s/\b${to_filter}//g")
    done
    make -f Makefile.orig CC=${NACLCC} ${passing_tests}
    # Special case -- needs an input file =(
    make -f Makefile.orig CC=${NACLCC} evp_test
  else
    # Plain make works better and doesn't muck with CC, etc.
    # Otherwise, we end up missing -ldl for GLIBC...
    make
  fi
  for test_name in ${passing_tests}; do
    RunSelLdrCommand ${test_name}
  done
  RunSelLdrCommand evp_test evptests.txt
}
