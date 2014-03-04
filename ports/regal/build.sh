#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}

# override the extract step since the github generated tarball
# puts all the files in regal-SHA1HASH folder
ExtractStep() {
  ArchiveName
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  Remove ${PACKAGE_NAME}
  MakeDir ${PACKAGE_NAME}
  ChangeDir ${PACKAGE_NAME}
  local tarball=${NACL_PACKAGES_TARBALLS}/${ARCHIVE_NAME}
  if [ $OS_SUBDIR = "windows" ]; then
    tar --strip-components=1 --no-same-owner -zxf ${tarball}
  else
    tar --strip-components=1 -zxf ${tarball}
  fi
}


BuildStep() {
  make -f Makefile SYSTEM=nacl-${NACL_ARCH}
}


InstallStep() {
  cp -a lib/nacl-${NACL_ARCH}/libRegal*.a ${NACLPORTS_LIBDIR}
  if [ "${NACL_GLIBC}" = 1 ]; then
    cp -a lib/nacl-${NACL_ARCH}/libRegal*.so* ${NACLPORTS_LIBDIR}
  fi
  cp -r include/GL ${NACLPORTS_INCLUDE}
}
