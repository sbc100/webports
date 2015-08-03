# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  EXTRA_CONFIGURE_ARGS+=" --enable-shared=no"
fi

InstallStep() {
    DefaultInstallStep
    if [ "${NACL_LIBC}" = "newlib" ]; then
        if ! grep -Eq "lglibc-compat" \
             ${INSTALL_DIR}/naclports-dummydir/lib/pkgconfig/x11.pc ; then
            sed -i.bak 's/-lX11/-lX11 -lglibc-compat/'\
                ${INSTALL_DIR}/naclports-dummydir/lib/pkgconfig/x11.pc
        fi
    fi
}

