#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


# TODO(sbc): Remove this once 32 becomes stable
# https://code.google.com/p/nativeclient/issues/detail?id=3599
if [ "$NACL_ARCH" = "pnacl" -a ${NACL_SDK_VERSION} -lt 32 ]; then
  NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS//-O2/}"
fi

export LIBS="-lm"

CONFIG_SUB=config/config.sub
