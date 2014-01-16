#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


EXECUTABLES="cjpeg djpeg jpegtran rdjpgcom wrjpgcom"

InstallStep() {
  MakeDir ${NACLPORTS_PREFIX}/man
}

TestStep() {
  for exe in ${EXECUTABLES}; do
    mv ${exe} ${exe}${NACL_EXEEXT}
  done

  if [ ${NACL_ARCH} = "pnacl" ]; then
    for arch in x86-32 x86-64; do
      for exe in ${EXECUTABLES}; do
        WriteSelLdrScriptForPNaCl ${exe} ${exe}.${arch}.nexe ${arch}
      done
      make test
    done
  else
    for exe in ${EXECUTABLES}; do
      WriteSelLdrScript ${exe} ${exe}${NACL_EXEEXT}
    done
    make test
  fi
}
