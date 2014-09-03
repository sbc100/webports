# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# without this configure fails with the error
# checking build system type... Invalid configuration \
#`x86_64-unknown-linux-': machine `x86_64-unknown-linux' not recognized
if [ $NACL_ARCH = "arm" ]; then
  export LIBC=newlib
fi

export PERL=/bin/true
export EXTRA_CONFIGURE_ARGS="--disable-arm-simd"
