#!/bin/bash
# Copyright (c) 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Samba doesn't seem to support building outside the source tree.
BUILD_DIR=${SRC_DIR}

#NACLPORTS_CPPFLAGS+=" -Dmain=nacl_main"

#NACLPORTS_LDFLAGS+=" -Wl,--undefined=nacl_main ${NACL_CLI_MAIN_LIB} \
#  -lppapi_simple \
#  -lnacl_io -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"

#NACLPORTS_LDFLAGS+="-lnacl_io"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  NACLPORTS_LDFLAGS+=" -lglibc-compat"
fi

ConfigureStep() {
  conf_build=$(/bin/sh "${SCRIPT_DIR}/config.guess")

  SetupCrossEnvironment

  local CONFIGURE=${NACL_CONFIGURE_PATH:-${SRC_DIR}/configure}
  local conf_host=${NACL_CROSS_PREFIX}
  if [ "${NACL_ARCH}" = "pnacl" -o "${NACL_ARCH}" = "emscripten" ]; then
    # The PNaCl tools use "pnacl-" as the prefix, but config.sub
    # does not know about "pnacl".  It only knows about "le32-nacl".
    # Unfortunately, most of the config.subs here are so old that
    # it doesn't know about that "le32" either.  So we just say "nacl".
    conf_host="nacl"
  fi

  # Inject a shim that speed up pnacl invocations for configure.
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    local PNACL_CONF_SHIM="${TOOLS_DIR}/pnacl-configure-shim.py"
    CC="${PNACL_CONF_SHIM} ${CC}"
  fi

  CC="${START_DIR}/cc_shim.sh ${CC}"

  # Specify both --build and --host options.  This forces autoconf into cross
  # compile mode.  This is useful since the autodection doesn't always works.
  # For example a trivial PNaCl binary can sometimes run on the linux host if
  # it has the correct LLVM bimfmt support. What is more, autoconf will
  # generate a warning if only --host is specified.
  LogExecute "${CONFIGURE}" \
    --build=${conf_build} \
    --hostcc=gcc \
    --cross-compile \
    --cross-answers=${START_DIR}/answers \
    --prefix=${PREFIX}
}

BuildStep() {
  WAF_ARGS="--targets=smbclient"
  if [ "${VERBOSE:-}" = "1" ]; then
    WAF_ARGS+=" -v"
  fi
  WAF_MAKE=1 LogExecute python ./buildtools/bin/waf build ${WAF_ARGS}
}

InstallStep() {
  return
}
