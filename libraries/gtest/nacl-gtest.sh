#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

CONFIG_SUB=build-aux/config.sub

CustomInstallStep() {
  # Add chmod here since gtest archive contains readonly files we don't
  # want installed files to be readonly
  LogExecute chmod -R +w .

  Remove ${NACLPORTS_LIBDIR}/libgtest*
  LogExecute install -m 644 lib/.libs/libgtest.a ${NACLPORTS_LIBDIR}/
  if [ "${NACL_GLIBC}" = "1" ]; then
    LogExecute install -m 644 lib/.libs/libgtest.so* ${NACLPORTS_LIBDIR}/
  fi

  Remove ${NACLPORTS_INCLUDE}/gtest
  LogExecute cp -r ../include/gtest ${NACLPORTS_INCLUDE}/gtest
}

CustomPackageInstall() {
   DefaultPreInstallStep
   DefaultDownloadStep
   DefaultExtractStep
   DefaultPatchStep
   DefaultConfigureStep
   DefaultBuildStep
   CustomInstallStep
   DefaultCleanUpStep
}

CustomPackageInstall
exit 0
