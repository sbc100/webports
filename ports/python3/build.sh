# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


EXECUTABLES=python${NACL_EXEEXT}

# Currently this package only builds on linux.
# The build relies on certain host binaries and python's configure
# requires us to set --build= as well as --host=.

HOST_BUILD_DIR=${WORK_DIR}/build_host
export PATH=${HOST_BUILD_DIR}/inst/usr/local/bin:${PATH}

BuildHostPython() {
  MakeDir ${HOST_BUILD_DIR}
  ChangeDir ${HOST_BUILD_DIR}
  if [ -f python -a -f Parser/pgen ]; then
    return
  fi
  LogExecute ${SRC_DIR}/configure
  LogExecute make -j${OS_JOBS} all
  LogExecute make install DESTDIR=inst
}

ConfigureStep() {
  BuildHostPython
  ChangeDir ${BUILD_DIR}
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
  export LIBS="-ltermcap"
  if [ "${NACL_LIBC}" = "newlib" ]; then
    NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
    LIBS+=" -lglibc-compat"
  fi
  DefaultConfigureStep
  if [ "${NACL_LIBC}" = "newlib" ]; then
    LogExecute cp ${START_DIR}/Setup.local Modules/
  fi
}

BuildStep() {
  export CROSS_COMPILE=true
  export MAKEFLAGS="PGEN=${HOST_BUILD_DIR}/Parser/pgen"
  SetupCrossEnvironment
  DefaultBuildStep
}

TestStep() {
  if [ ${NACL_ARCH} = "pnacl" ]; then
    local pexe=python${NACL_EXEEXT}
    local script=python
    # on Mac/Windows the folder called Python prevents us from creating a
    # script called python (lowercase).
    if [ ${OS_NAME} != "Linux" ]; then
      script+=".sh"
    fi
    TranslateAndWriteSelLdrScript ${pexe} x86-64 python.x86-64.nexe ${script}
  fi
}
