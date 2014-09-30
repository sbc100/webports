# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="test/cairo-test-suite${NACL_EXEEXT}"

# This is only necessary for pnacl
export ax_cv_c_float_words_bigendian=no

# For now disable use of x11 related libraries.
EXTRA_CONFIGURE_ARGS+=" --enable-xlib=no"
EXTRA_CONFIGURE_ARGS+=" --enable-xlib-xrender=no"
EXTRA_CONFIGURE_ARGS+=" --enable-xcb=no"
EXTRA_CONFIGURE_ARGS+=" --enable-xlib-xcb=no"
