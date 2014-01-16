#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXTRA_CONFIGURE_ARGS="--with-apr=${NACLPORTS_PREFIX}"
EXTRA_CONFIGURE_ARGS+=" --with-apr-util=${NACLPORTS_PREFIX}"
