#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXTRA_CONFIGURE_ARGS="--disable-docs --with-arch=x86"

# The configure script for fontconfig uses AC_PATH_PROG rather than
# AC_PATH_TOOL when looking for freetype-config, so it doesn't finds the
# system one rather than one in the toolchain.
EXTRA_CONFIGURE_ARGS+=" --with-freetype-config=${NACL_PREFIX}/bin/freetype-config"
