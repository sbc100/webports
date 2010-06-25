#!/bin/bash
# Copyright (c) 2010 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that be
# found in the LICENSE file.
#

# nacl-OpenSceneGraph-2.9.7.sh
#
# usage:  nacl-OpenSceneGraph-2.9.7.sh
#
# This script uses the patch-OpenSceneGraph script to download and patch
# OpenSceneGraph, then builds OpenSceneGraph for Native Client
#

source patch-OpenSceneGraph-2.9.7.sh

CustomPackageInstall() {
   DefaultBuildStep
   CustomInstallStep
   DefaultCleanUpStep
}

CustomPackageInstall
exit 0
