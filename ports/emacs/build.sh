#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export RUNPROGRAM="${NACL_SEL_LDR} -a -B ${NACL_IRT} -- ${NACL_SDK_LIB}/runnable-ld.so --library-path ${NACL_SDK_LIBDIR}:${NACL_SDK_LIB}:${NACLPORTS_LIBDIR}"
export NACL_SEL_LDR
export RUNPROGRAM_ARGS="-a -B ${NACL_IRT} -- ${NACL_SDK_LIB}/runnable-ld.so --library-path ${NACL_SDK_LIBDIR}:${NACL_SDK_LIB}:${NACLPORTS_LIBDIR}"

ConfigureStep() {
  export CFLAGS="${NACLPORTS_CFLAGS} -I${NACL_SDK_ROOT}/include"
  DefaultConfigureStep
}

# Build twice to workaround a problem in the build script that builds something
# partially the first time that makes the second time succeed
BuildStep() {
  DefaultBuildStep || DefaultBuildStep
}

PatchStep() {
  DefaultPatchStep

  ChangeDir ${SRC_DIR}
  rm -f lisp/emacs-lisp/bytecomp.elc
  rm -f lisp/files.elc
  rm -f lisp/international/quail.elc
}
