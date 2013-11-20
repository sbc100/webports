#!/bin/bash
# Copyright 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

ConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  Remove ${NACL_BUILD_SUBDIR}
  MakeDir ${NACL_BUILD_SUBDIR}
  cd ${NACL_BUILD_SUBDIR}
  echo "Directory: $(pwd)"

  CC="${NACLCC}" CXX="${NACLCXX}" cmake ..\
           -DCMAKE_TOOLCHAIN_FILE=../XCompile-nacl.txt \
           -DNACLAR=${NACLAR} \
           -DNACLLD=${NACLLD} \
           -DNACL_CROSS_PREFIX=${NACL_CROSS_PREFIX} \
           -DNACL_SDK_ROOT=${NACL_SDK_ROOT} \
           -DCMAKE_INSTALL_PREFIX=${NACLPORTS_PREFIX} \
           -DCMAKE_BUILD_TYPE=RELEASE \
           -DBUILD_SHARED_LIBS=OFF \
           -DWITH_FFMPEG=OFF \
           -DWITH_OPENEXR=OFF \
           -DWITH_CUDA=OFF \
           -DWITH_JASPER=OFF \
           -DWITH_JPEG=OFF \
           -DWITH_OPENCL=OFF \
           -DBUILD_opencv_apps=OFF \
           -DBUILD_TESTS=OFF \
           -DBUILD_PERF_TESTS=OFF
}

BuildStep() {
  make clean
  # opencv build can fail when build with -jN.
  make
}

PackageInstall
exit 0
