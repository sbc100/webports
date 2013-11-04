#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

# readline has config.sub in a 'support' subfolder
CONFIG_SUB=support/config.sub
MAKEFLAGS+=" EXEEXT=.nexe"

if [ "${NACL_GLIBC}" != "1" ]; then
   NACLPORTS_CFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
   EXTRA_CONFIGURE_ARGS="--disable-shared"
   export LIBS=-lglibc-compat
fi


TestStep() {
  Banner "Testing ${PACKAGE_NAME}"
  if [ "${NACL_GLIBC}" != "1" ]; then
    # readline example don't link under sel_ldr
    # TODO(sbc): find a way to add glibc-compat/nosys to link line for examples.
    return
  fi
  MAKE_TARGETS=examples
  DefaultBuildStep
  cd examples
  # TODO(jvoung): PNaCl can't use WriteSelLdrScript --
  # It should use TranslateAndWriteSelLdrScript instead.
  # It probably shouldn't use .nexe as the extension either.
  for NEXE in *.nexe; do
    WriteSelLdrScript ${NEXE%.*} ${NEXE}
  done
}


PackageInstall() {
  DefaultPackageInstall
  if [ "${NACL_GLIBC}" = "1" ]; then
    cd ${NACLPORTS_LIBDIR}
    ln -sf libreadline.so.6 libreadline.so
    cd -
  fi
}


PackageInstall
exit 0
