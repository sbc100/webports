# Copyright 2016 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EnableCliMain
EnableGlibcCompat
EXTRA_CONFIGURE_ARGS+=" --without-gtk --with-nettle"
EXECUTABLES=stoken${NACL_EXEEXT}

# Workaround for pthread link order problem (copied from libarchive).
export LIBS="-lpthread -lm"
