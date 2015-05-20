# Copyright 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Workaround for arm-gcc bug:
# https://code.google.com/p/nativeclient/issues/detail?id=3205
# TODO(sbc): remove this once the issue is fixed
if [ "${NACL_ARCH}" = "arm" ]; then
  NACLPORTS_CPPFLAGS+=" -mfpu=vfp"
fi

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
fi

EXTRA_CMAKE_ARGS="-DTEST=ON"
EXECUTABLES="convert libyuv_unittest"

TestStep() {
  # TODO(sbc): re-enable i686 testing once we fix this gtest-releated issue:
  # http://crbug.com/434821
  if [ "${NACL_ARCH}" = "i686" ]; then
    return
  fi
  if [ "${NACL_ARCH}" = pnacl ]; then
    return
  fi
  LogExecute ./libyuv_unittest.sh --gtest_filter=-libyuvTest.ARGBRect_Unaligned
}
