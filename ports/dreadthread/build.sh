#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BuildStep() {
  MakeDir ${SRC_DIR}
  ChangeDir ${SRC_DIR}
  ${NACLCC} -c ${START_DIR}/dread.c -o dread.o
  ${NACLCC} -c ${START_DIR}/dread_chain.c -o dread_chain.o
  ${NACLAR} rcs libdreadthread.a \
      dread.o \
      dread_chain.o
  ${NACLRANLIB} libdreadthread.a
}

InstallStep() {
  cp ${SRC_DIR}/libdreadthread.a ${NACLPORTS_LIBDIR}
  cp ${START_DIR}/dreadthread.h ${NACLPORTS_INCLUDE}
  cp ${START_DIR}/dreadthread_ctxt.h ${NACLPORTS_INCLUDE}
  cp ${START_DIR}/dreadthread_chain.h ${NACLPORTS_INCLUDE}
}
