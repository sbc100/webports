# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

InstallStep() {
  MakeDir ${DESTDIR_LIB}
  MakeDir ${DESTDIR_INCLUDE}

  LogExecute install -m 644 lib/.libs/libgtest*.a ${DESTDIR_LIB}/
  if [ "${NACL_SHARED}" = "1" ]; then
    LogExecute install -m 644 lib/.libs/libgtest.so* ${DESTDIR_LIB}/
  fi

  LogExecute cp -r --no-preserve=mode ${SRC_DIR}/include/gtest \
    ${DESTDIR_INCLUDE}/gtest
}
