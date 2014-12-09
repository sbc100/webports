#!/bin/bash
# Copyright 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Installs required python modules using 'pip'.
# If 'pip' executable is not found in PATH then install that first.
# Installs are performed with the --user argument which means that
# root privileges are not required and PYTHONUSERBASE is set to point
# to the local 'out' directory so installs are local to naclports.

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"
cd "${SCRIPT_DIR}/.."

export PYTHONUSERBASE=$PWD/out/pip
export PATH=$PATH:$PYTHONUSERBASE/bin

pip=$(which pip)
set -e
if [ -z "$pip" ]; then
  echo "Installing pip.."
  # Use local file rather than pipeline so we can detect failure of the curl
  # command.
  curl --silent --show-error https://bootstrap.pypa.io/get-pip.py > get-pip.py
  python get-pip.py --user
  rm -f get-pip.py
fi

ARGS="--no-compile --download-cache=out/cache/pip"
set -x
pip install $ARGS --user -r requirements.txt
