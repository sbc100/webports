#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Echo the environment variables need to to build/configure standard
# GNU make/automake/configure projects.
#
# To import these variables into your environment do:
# $ eval $(nacl_env.sh)

SCRIPT_DIR=$(cd "$(dirname "$BASH_SOURCE")"; pwd)
. ${SCRIPT_DIR}/common.sh

echo "export CC=${NACLCC}"
echo "export CXX=${NACLCXX}"
echo "export AR=${NACLAR}"
echo "export RANLIB=${NACLRANLIB}"
echo "export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig"
echo "export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}"
echo "export FREETYPE_CONFIG=${NACLPORTS_PREFIX_BIN}/freetype-config"
echo "export PATH=${NACL_BIN_PATH}:${PATH}"
echo "export CFLAGS=\"${NACLPORTS_CFLAGS}\""
echo "export LDFLAGS=\"${NACLPORTS_LDFLAGS}\""
