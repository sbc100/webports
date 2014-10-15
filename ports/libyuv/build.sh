# Copyright 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="convert libyuv_unittest"

TestStep() {
  if [ "${NACL_ARCH}" != pnacl ]; then
    ./libyuv_unittest.sh
  fi
}
