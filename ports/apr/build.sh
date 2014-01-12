#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

export RUNPROGRAM="${NACL_SEL_LDR} -a -B ${NACL_IRT} --"
RUNPROGRAM+=" ${NACL_SDK_LIB}/runnable-ld.so"
RUNPROGRAM+=" --library-path"
RUNPROGRAM+=" ${NACL_SDK_LIBDIR}:${NACL_SDK_LIB}:${NACLPORTS_LIBDIR}"
export NACL_SEL_LDR

PackageInstall
exit 0
