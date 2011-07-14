#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# The nacl-install-linux-*.sh scripts should source this script.
#

set -o nounset
set -o errexit

RESULT=0
MESSAGES=

BuildPackage() {
  if make $1 ; then
    echo "naclports nacl-install-all: Install SUCCEEDED $1 \
($NACL_PACKAGES_BITSIZE)"
  else
     MESSAGE="naclports nacl-install-all: Install FAILED for $1 \
($NACL_PACKAGES_BITSIZE)"
    echo $MESSAGE
    echo "@@@STEP_FAILURE@@@"
    MESSAGES="$MESSAGES\n$MESSAGE"
    RESULT=1
  fi
}
