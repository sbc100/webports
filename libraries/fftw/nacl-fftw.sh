#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-fftw-3.2.2.sh
#
# usage:  nacl-fftw-3.2.2.sh
#
# This script downloads, patches, and builds fftw-3.2.2 for Native Client.
#

source pkg_info
source ../../build_tools/common.sh

if [ ${NACL_ARCH} = "i686" -o ${NACL_ARCH} = 'x86_64' ] ; then
  EXTRA_CONFIGURE_ARGS="--enable-sse2"
fi

DefaultPackageInstall
exit 0
