#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


export LIBS="-lnacl_io"

if [ "${NACL_GLIBC}" != "1" ]; then
   NACLPORTS_CFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
   NACLPORTS_CXXFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
   export LIBS="${LIBS} -lglibc-compat"
fi

if [ "{NACL_ARCH}" = "pnacl" ]; then
   NACLPORTS_CFLAGS+=" -DBYTE_ORDER=LITTLE_ENDIAN"
   NACLPORTS_CXXFLAGS+=" -DBYTE_ORDER=LITTLE_ENDIAN"
fi

NACLPORTS_CFLAGS+=" -DZMQ_FORCE_MUTEXES"
NACLPORTS_CXXFLAGS+=" -DZMQ_FORCE_MUTEXES"

ConfigureStep() {
  export CROSS_COMPILE=true
  EXTRA_CONFIGURE_ARGS+=" --disable-shared --enable-static --with-poller=poll"
  DefaultConfigureStep
}
