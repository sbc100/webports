#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# TODO(binji): support PNG.
# This is the error when building with png.
#
#   `libpng-config' should not be used in cross-building;
#   either set the LIBPNG_CFLAGS and LIBPNG_LDFLAGS environment variables,
#   or pass `--without-png' to the `configure' script.
EXTRA_CONFIGURE_ARGS="--without-png"

PatchStep() {
  DefaultPatchStep
  ChangeDir ${SRC_DIR}
  Banner "Patching configure"
  ${TOOLS_DIR}/patch_configure.py builds/unix/configure
}
