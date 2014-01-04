#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

if [ "${NACL_GLIBC}" != "1" ]; then
   NACLPORTS_CFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
   NACLPORTS_CFLAGS+=" -DBYTE_ORDER=LITTLE_ENDIAN"
   NACLPORTS_CXXFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
   NACLPORTS_CXXFLAGS+=" -DBYTE_ORDER=LITTLE_ENDIAN"
   export LIBS="-lnacl_io -lglibc-compat"
fi

ConfigureStep() {
  export CROSS_COMPILE=true
  EXTRA_CONFIGURE_ARGS+=" --disable-shared --enable-static --with-poller=poll"
  DefaultConfigureStep
}

PackageInstall
exit 0
