# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

NACLPORTS_CPPFLAGS+=" ${NACL_EXCEPTIONS_FLAG}"
EXECUTABLES="
examples/id3tag
examples/id3cp
examples/id3info
examples/id3convert
"
