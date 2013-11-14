#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

ConfigureStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  echo "using gcc : 4.4.3 : ${NACLCXX} ;" > tools/build/v2/user-config.jam
}

BuildStep() {
  ./bootstrap.sh

  # TODO(eugenis): build dynamic libraries, too
  if [ $NACL_GLIBC = "1" ] ; then
    ./bjam install \
      --prefix=${NACLPORTS_PREFIX} \
      link=static \
      -d+2 \
      --without-python \
      --without-signals \
      --without-mpi
  else
    ./bjam install \
      --prefix=${NACLPORTS_PREFIX} \
      link=static \
      -d+2 \
      --with-date_time \
      --with-program_options
  fi
}

InstallStep() {
  echo "Install is done by build step"
}

PackageInstall
exit 0
