#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

export NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS} -DMAXPATHLEN=512 -DHAVE_STDARG_H"
export NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS} -Dcompat_makedev\(a,b\)"
export LIBS="-lnosys"

DefaultPackageInstall

exit 0
