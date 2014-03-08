#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


BuildStep() {
  ChangeDir ${SRC_DIR}
  local cflags="${NACLPORTS_CFLAGS} -I${NACLPORTS_INCLUDE}/freetype2"
  if [ ${NACL_ARCH} != "pnacl" ]; then
    cflags="${cflags} -O3 -fomit-frame-pointer"
  fi
  if [ ${NACL_ARCH} = "i686" -o ${NACL_ARCH} = "x86_64" ]; then
    cflags="${cflags} -mfpmath=sse -msse"
  fi
  MAKEFLAGS="-j${OS_JOBS}" AGGCXXFLAGS="${cflags}" LogExecute make -j${OS_JOBS}
}


InstallStep() {
  # copy libs and headers manually
  ChangeDir ${NACLPORTS_INCLUDE}
  Remove ${PACKAGE_NAME}
  MakeDir ${PACKAGE_NAME}
  cp -R ${SRC_DIR}/include/*.h ${PACKAGE_NAME}/
  cp ${SRC_DIR}/font_freetype/*.h ${PACKAGE_NAME}/
  ChangeDir ${NACLPORTS_LIBDIR}
  cp ${SRC_DIR}/src/libagg.a .
  cp ${SRC_DIR}/font_freetype/libaggfontfreetype.a .
}
