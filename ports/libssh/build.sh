# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXTRA_CMAKE_ARGS="\
  -DPNACL=ON\
  -DWITH_STATIC_LIB=ON\
  -DWITH_SHARED_LIB=OFF\
  -DWITH_EXAMPLES=OFF\
  -DHAVE_GETADDRINFO=ON
"
