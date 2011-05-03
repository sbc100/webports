#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
cd ${SCRIPT_DIR}/../packages

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
