#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


# readline has config.sub in a 'support' subfolder
CONFIG_SUB=support/config.sub
MAKEFLAGS+=" EXEEXT=.${NACL_EXEEXT}"

if [ "${NACL_GLIBC}" != "1" ]; then
   NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
   EXTRA_CONFIGURE_ARGS="--disable-shared"
   export LIBS="-lglibc-compat"
fi


TestStep() {
  if [ "${NACL_GLIBC}" != "1" ]; then
    # readline example don't link under sel_ldr
    # TODO(sbc): find a way to add glibc-compat to link line for examples.
    return
  fi
  MAKE_TARGETS=examples
  DefaultBuildStep
  pushd examples
  # TODO(jvoung): PNaCl can't use WriteSelLdrScript --
  # It should use TranslateAndWriteSelLdrScript instead.
  # It probably shouldn't use .nexe as the extension either.
  for NEXE in *.nexe; do
    WriteSelLdrScript ${NEXE%.*} ${NEXE}
  done
  popd
}


InstallStep() {
  DefaultInstallStep
  if [ "${NACL_GLIBC}" = "1" ]; then
    cd ${NACLPORTS_LIBDIR}
    ln -sf libreadline.so.6 libreadline.so
    cd -
  fi
}
