#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-gsl-1.9.sh
#
# usage:  nacl-gsl-1.9.sh
#
# this script downloads, patches, and builds gsl for Native Client
#

source pkg_info

export LIBS="-lm"

source ../../build_tools/common.sh

DefaultPackageInstall
exit 0
