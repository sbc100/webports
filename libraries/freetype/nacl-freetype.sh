#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../build_tools/common.sh

InstallStep() {
  # do the regular make install
  make install
  # move freetype up a directory so #include <freetype/freetype.h> works...
  Remove ${NACLPORTS_INCLUDE}/freetype
  cp -R ${NACLPORTS_INCLUDE}/freetype2/freetype ${NACLPORTS_INCLUDE}/.
  Remove ${NACLPORTS_INCLUDE}/freetype2
}

PatchStep() {
  DefaultPatchStep
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  Banner "Patching configure"
  ${TOOLS_DIR}/patch_configure.py builds/unix/configure
}

PackageInstall
exit 0
