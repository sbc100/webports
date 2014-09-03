# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

if [ "${NACL_SHARED}" = "1" ]; then
  NACLPORTS_CFLAGS+=" -fPIC"
fi

# define LONGLONG_STANDALONE so that longlong.h doesn't
# contain references to machine-dependant functions.
# This is needed in particular on ARM but is correct on
# all platforms since we don't compile machine-depenedant
# files.
NACLPORTS_CFLAGS+=" -DLONGLONG_STANDALONE"

# Disable all assembly code by specifying none-none-none.
EXTRA_CONFIGURE_ARGS=--host=none-none-none
