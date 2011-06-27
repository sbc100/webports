#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -x
set -e

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
cd ${SCRIPT_DIR}/../packages

echo "@@@BUILD_STEP nacl-mounts test@@@"
cd scripts/nacl-mounts
make clean && make all && ./tests_out/nacl_mounts_tests
cd ../../

export NACL_SDK_ROOT="${SCRIPT_DIR}/../"

# TODO: Eliminate this dependency if possible.
# This is required on OSX so that the naclports version of pkg-config can be
# found.
export PATH=${PATH}:/opt/local/bin

if ! "./nacl-install-all.sh" ; then
  echo "Error building!" 1>&2
  exit 1
fi

exit 0
