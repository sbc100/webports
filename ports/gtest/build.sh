# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

ExtractStep() {
  DefaultExtractStep
  # Add chmod here since gtest archive contains readonly files we don't
  # want installed files to be readonly
  LogExecute chmod -R +w ${SRC_DIR}
}

InstallStep() {
  MakeDir ${DESTDIR_LIB}
  MakeDir ${DESTDIR_INCLUDE}

  LogExecute install -m 644 lib/.libs/libgtest.a ${DESTDIR_LIB}/
  if [ "${NACL_SHARED}" = "1" ]; then
    LogExecute install -m 644 lib/.libs/libgtest.so* ${DESTDIR_LIB}/
  fi

  LogExecute cp -r ${SRC_DIR}/include/gtest ${DESTDIR_INCLUDE}/gtest
}
