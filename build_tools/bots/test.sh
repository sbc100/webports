#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# This script tests the buildbot configuration.
# Specifically, it tests that the package list shards don't
# include invalid package names or missing dependencies.

SCRIPT_DIR="$(cd $(dirname $0) && pwd)"

. ${SCRIPT_DIR}/bot_common.sh

CalculatePackageShards

exit 0
