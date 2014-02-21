#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

ConfigureStep() {
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PATH=${NACL_BIN_PATH}:${PATH}
  export LIB_GMOCK=libgmock.a
}

InstallStep() {
  Remove ${NACLPORTS_INCLUDE}/gmock
  (ChangeDir include; tar cf - gmock | (ChangeDir ${NACLPORTS_INCLUDE}; tar xfp -))
  Remove ${NACLPORTS_LIBDIR}/${LIB_GMOCK}
  install -m 644 ${LIB_GMOCK} ${NACLPORTS_LIBDIR}/${LIB_GMOCK}
}
