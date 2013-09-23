#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

EXECUTABLES=python${NACL_EXEEXT}

# Currently this package only builds on linux.
# The build relies on certain host binaries and python's configure
# requires us to set --build= as well as --host=.

BuildHostPython() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  MakeDir build-nacl-host
  ChangeDir build-nacl-host
  if [ -f python -a -f Parser/pgen ]; then
    return
  fi
  # Reset CFLAGS and LDFLAGS when configuring the host
  # version of python since they hold values designed for
  # building for NaCl.
  CFLAGS="" LDFLAGS="" LogExecute ../configure
  LogExecute make -j${OS_JOBS} python Parser/pgen
}

ConfigureStep() {
  BuildHostPython
  export CROSS_COMPILE=true
  # We pre-seed configure with certain results that it cannot determine
  # since we are doing a cross compile.  The $CONFIG_SITE file is sourced
  # by configure early on.
  export CONFIG_SITE=${START_DIR}/config.site
  # Disable ipv6 since configure claims it requires a working getaddrinfo
  # which we do not provide.  TODO(sbc): remove this once nacl_io supports
  # getaddrinfo.
  EXTRA_CONFIGURE_ARGS="--disable-ipv6"
  EXTRA_CONFIGURE_ARGS+=" --with-suffix=${NACL_EXEEXT}"
  EXTRA_CONFIGURE_ARGS+=" --build=x86_64-linux-gnu"
  export MAKEFLAGS="PGEN=../build-nacl-host/Parser/pgen"
  export LIBS="-ltermcap"
  if [ "${NACL_GLIBC}" != "1" ]; then
    LIBS+=" -lglibc-compat -lc -lnosys"
  fi
  DefaultConfigureStep
  if [ "${NACL_GLIBC}" != "1" ]; then
    LogExecute cp ${START_DIR}/Setup.local Modules/
  fi
}

TestStep() {
  WriteSelLdrScript python python${NACL_EXEEXT}
}

PackageInstall() {
  DefaultPackageInstall
  TestStep
}

PackageInstall
exit 0
