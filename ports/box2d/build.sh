#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


TestStep() {
  Banner "Testing ${PACKAGE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}/${NACL_BUILD_SUBDIR}
  ChangeDir HelloWorld
  RunSelLdrCommand HelloWorld
}

ConfigureStep() {
  EXTRA_CMAKE_ARGS="-DBOX2D_BUILD_EXAMPLES=OFF"
  CMakeConfigureStep
}
