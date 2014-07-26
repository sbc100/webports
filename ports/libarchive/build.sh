#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXTRA_CONFIGURE_ARGS="--disable-bsdtar --disable-bsdcpio"
EXTRA_CONFIGURE_ARGS+=" --without-iconv"

NACLPORTS_CPPFLAGS+=" -Dtimezone=_timezone"

# Necessary for libxml2.
export LIBS="-lpthread -lm"
