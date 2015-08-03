# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  NACLPORTS_LDFLAGS+=" -lglibc-compat"
fi

InstallStep() {
    DefaultInstallStep
    if [ "${NACL_LIBC}" = "newlib" ]; then
        if ! grep -Eq "lglibc-compat" \
             ${INSTALL_DIR}/naclports-dummydir/lib/pkgconfig/xcb.pc ; then
            sed -i.bak 's/-lxcb/-lxcb -lglibc-compat/'\
                ${INSTALL_DIR}/naclports-dummydir/lib/pkgconfig/xcb.pc
        fi
    fi
}

NACLPORTS_LDFLAGS+=" -lnacl_io -l${NACL_CXX_LIB}"
