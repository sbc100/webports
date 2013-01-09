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
readonly PATCH_FILE=nacl-openssl-1.0.0e.patch
readonly PACKAGE_NAME=openssl-1.0.0e

source ../../build_tools/common.sh

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  local extra_args=""
  if [[ "${NACL_ARCH}" = "pnacl" ||
        "${NACL_TOOLCHAIN_ROOT}" == *newlib* ]] ; then
    readonly GLIBC_COMPAT=${NACL_SDK_USR_INCLUDE}/glibc-compat
    if [[ ! -f ${GLIBC_COMPAT}/netdb.h ]]; then
      echo "Please install glibc-compat first"
      exit 1
    fi
    extra_args+=" no-dso -DOPENSSL_NO_SOCK=1 -I${GLIBC_COMPAT}"
  fi

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  MACHINE=i686 CC=${NACLCC} AR=${NACLAR} RANLIB=${NACLRANLIB} ./config \
     --prefix=${NACL_SDK_USR} no-asm no-hw no-krb5 ${extra_args} -D_GNU_SOURCE
}

CustomHackStepForNewlib() {
  # These two makefiles build binaries which we do not care about,
  # and they depend on -ldl, so cannot be built with newlib.
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
  DefaultPatchStep
  CustomConfigureStep
  if [[ "${NACL_ARCH}" = "pnacl" ||
	"${NACL_TOOLCHAIN_ROOT}" == *newlib* ]] ; then
    CustomHackStepForNewlib
  fi
  CustomBuildStep
  DefaultInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
