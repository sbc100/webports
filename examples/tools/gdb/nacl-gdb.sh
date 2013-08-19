#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../../build_tools/common.sh

PackageInstall() {
  DefaultPreInstallStep
  GitCloneStep
  DefaultPatchStep
}

PackageInstall
exit 0
