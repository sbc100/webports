# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BuildStep() {
  return
}

InstallStep() {
  MakeDir ${INSTALL_DIR}${PREFIX}
  ChangeDir ${INSTALL_DIR}${PREFIX}

  MakeDir lib

  # Copy SDK libs
  LogExecute cp -r ${NACL_SDK_LIBDIR}/* lib/

  # Copy in SDK includes.
  LogExecute cp -r ${NACL_SDK_ROOT}/include ./
  LogExecute rm -fr include/gtest
  LogExecute rm -fr include/gmock
  LogExecute rm -fr lib/libgtest.*
  LogExecute rm -fr lib/libgmock.*
}
