#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

if [ "${NACL_LIBC}" = "newlib" ]; then
  readonly GLIBC_COMPAT=${NACLPORTS_INCLUDE}/glibc-compat
  NACLPORTS_CPPFLAGS+=" -I${GLIBC_COMPAT}"
fi

if [ "${NACL_SHARED}" = "0" ]; then
  EXTRA_CONFIGURE_ARGS="--disable-dso"
fi
