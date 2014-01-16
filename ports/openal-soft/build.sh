#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


# Defaults to dynamic lib, but newlib can only link statically.
if [[ ${NACL_GLIBC} = 0 ]]; then
  EXTRA_CMAKE_ARGS="-DLIBTYPE=STATIC"
fi

ConfigureStep() {
  CMakeConfigureStep
}
