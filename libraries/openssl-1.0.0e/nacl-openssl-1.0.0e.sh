#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-openssl-1.0.0e.sh
#
# usage:  nacl-openssl-1.0.0e.sh
#
# this script downloads, patches, and builds openssl for Native Client
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/openssl-1.0.0e.tar.gz
#readonly URL=http://www.openssl.org/source/openssl-1.0.0e.tar.gz
readonly PATCH_FILE=
readonly PACKAGE_NAME=openssl-1.0.0e

source ../../build_tools/common.sh


CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  local extra_args=""
  if [[ "${NACL_PACKAGES_BITSIZE}" = "pnacl" ||
	"${NACL_TOOLCHAIN_ROOT}" == *newlib* ]] ; then
    extra_args+=" no-dso -DOPENSSL_NO_SOCK=1 "
  fi

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  MACHINE=i686 CC=${NACLCC} AR=${NACLAR} RANLIB=${NACLRANLIB} ./config \
     --prefix=${NACL_SDK_USR} no-asm no-hw no-krb5 ${extra_args} -D_GNU_SOURCE
}

# This is a little brutal but gives us a nice way to track progress.
# We need to indentify the files which other project
# may need and then make sure they can be builte with newlib,
#
# Note: things that are likely needed: crypto/rand/rand_unix.c
CustomHackStepForNewlib() {
  local bad="crypto/bio/bss_fd.c
             crypto/bio/bss_sock.c
             crypto/bio/bss_conn.c
             crypto/bio/b_sock.c
             crypto/bio/bss_acpt.c
             crypto/bio/bss_log.c
             crypto/bio/bss_dgram.c
             crypto/rand/rand_egd.c
             crypto/rand/rand_unix.c
             crypto/ui/ui_openssl.c
             crypto/pkcs7/bio_pk7.c
             ssl/d1_lib.c"

  echo "patching ssl/ssl_locl.h"
  # removing this include makes the crucial files
  # ssl/s3_pkt.c and ssl/s23_pkt.c and the not so crucial file
  # ssl/d1_pkt.c compile
  # but for some reason just clearing out e_os.h does not work
  # Note: pretty much all the other files listed as bad do include
  # e_os.h via some level of indirection as well
  sed -i -e 's/#include "e_os.h"/#define clear_sys_error() errno=0/' \
      ssl/ssl_locl.h

  for f in ${bad} ; do
    echo "newlib hack removing: $f"
    rm $f
    echo "/* removed - newlib incompatible */" > $f
  done

  echo "patching crypto/rand/rand_unix.c"
  echo
  echo "IMPORTAMT: someone with a clue needs to check/fix this!"
  echo "           What is the entropy source for openssl in nacl?"
  echo
  echo "int RAND_poll(void) { return 0; } " > crypto/rand/rand_unix.c

  # this is probably ok
  echo "patching crypto/ui/ui_openssl.c"
  echo "void* UI_OpenSSL(void) { return 0; } " > crypto/ui/ui_openssl.c


  # These two makefiles build binaries which we do not care about
  echo "all clean install: " > apps/Makefile
  echo "all clean install: " > test/Makefile
}

CustomBuildStep() {
  make clean
  make build_libs
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  # openssl doesn't need patching, so no patch step
  CustomConfigureStep
  if [[ "${NACL_PACKAGES_BITSIZE}" = "pnacl" ||
	"${NACL_TOOLCHAIN_ROOT}" == *newlib* ]] ; then
      CustomHackStepForNewlib
  fi
  CustomBuildStep
  DefaultInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
