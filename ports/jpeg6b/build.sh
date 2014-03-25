#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


EXECUTABLES="\
  cjpeg${NACL_EXEEXT} \
  djpeg${NACL_EXEEXT} \
  jpegtran${NACL_EXEEXT} \
  rdjpgcom${NACL_EXEEXT} \
  wrjpgcom${NACL_EXEEXT}"

BuildStep() {
  DefaultBuildStep
  for exe in ${EXECUTABLES}; do
    mv ${exe%%${NACL_EXEEXT}} ${exe}
  done
}

InstallStep() {
  # Don't install jpeg6b by default since it would
  # conflict with jpeg8.
  return
}

TestStep() {
  if [ ${NACL_ARCH} = "pnacl" ]; then
    for arch in x86-32 x86-64; do
      for exe in ${EXECUTABLES}; do
        local exe_noext=${exe%.*}
        WriteSelLdrScriptForPNaCl ${exe_noext} ${exe_noext}.${arch}.nexe ${arch}
      done
      make test
    done
  else
    make test
  fi
}
