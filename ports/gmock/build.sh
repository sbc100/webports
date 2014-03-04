#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

CONFIG_SUB=build-aux/config.sub

PatchStep() {
  DefaultPatchStep
  CONFIG_SUB=gtest/build-aux/config.sub
  PatchConfigSub
}

InstallStep() {
  LIB_GMOCK=libgmock.a
  Remove ${NACLPORTS_INCLUDE}/gmock
  tar -C ${SRC_DIR}/include -cf - gmock | tar -C ${NACLPORTS_INCLUDE} -xpf -
  Remove ${NACLPORTS_LIBDIR}/${LIB_GMOCK}
  install -m 644 lib/.libs/${LIB_GMOCK} ${NACLPORTS_LIBDIR}/${LIB_GMOCK}
}
