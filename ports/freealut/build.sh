# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

if [ "${NACL_SHARED}" = "1" ]; then
  EXECUTABLES="examples/.libs/playfile examples/.libs/hello_world"
else
  EXECUTABLES="examples/playfile examples/hello_world"
fi

# Without this openal is not detected
export LIBS="-lm"
