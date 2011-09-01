#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
cd ${SCRIPT_DIR}/..

export NACL_SDK_ROOT="${SCRIPT_DIR}/../"

if ! make clean ; then
  echo "Error cleaning!" 1>&2
  exit 1
fi

exit 0
