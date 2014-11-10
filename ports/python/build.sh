# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES=python${NACL_EXEEXT}

# This build relies on certain host binaries and python's configure
# requires us to set --build= as well as --host=.
HOST_BUILD_DIR=${WORK_DIR}/build_host

ConfigureStep() {
  # We pre-seed configure with certain results that it cannot determine
  # since we are doing a cross compile.  The $CONFIG_SITE file is sourced
  # by configure early on.
  export CROSS_COMPILE=true
  export CONFIG_SITE=${START_DIR}/config.site
  # Disable ipv6 since configure claims it requires a working getaddrinfo
  # which we do not provide.  TODO(sbc): remove this once nacl_io supports
  # getaddrinfo.
  EXTRA_CONFIGURE_ARGS="--disable-ipv6"
  EXTRA_CONFIGURE_ARGS+=" --with-suffix=${NACL_EXEEXT}"
  EXTRA_CONFIGURE_ARGS+=" --build=x86_64-linux-gnu"
  export LIBS="-ltermcap"
  if [ "${NACL_LIBC}" = "newlib" ]; then
    LIBS+=" -lglibc-compat"
  fi
  DefaultConfigureStep
  if [ "${NACL_LIBC}" = "newlib" ]; then
    # For static linking we copy in a pre-baked Setup.local
    LogExecute cp ${START_DIR}/Setup.local Modules/
  fi
}

BuildStep() {
  export CROSS_COMPILE=true
  export MAKEFLAGS="PGEN=${NACL_HOST_PYBUILD}/Parser/pgen"
  SetupCrossEnvironment
  DefaultBuildStep
}

InstallStep() {
  export CROSS_COMPILE=true
  DefaultInstallStep
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
