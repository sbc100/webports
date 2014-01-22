#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}

InstallStep() {
  # copy libs and headers manually
  LogExecute cp src/headers/*.h ${NACLPORTS_INCLUDE}
  LogExecute cp *.a ${NACLPORTS_LIBDIR}
}
