#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


AutogenStep() {
  ChangeDir ${SRC_DIR}
  # For some reason if we don't remove configure before running
  # autoconf it doesn't always get updates correctly.  About half
  # the time the old configure script (with no reference to nacl)
  # will remain after ./autogen.sh
  rm -f configure
  ./autogen.sh
  PatchConfigure
  PatchConfigSub
  cd -
}


ConfigureTests() {
  Banner "Configuring tests for ${PACKAGE_NAME}"

  SetupCrossEnvironment
  local conf_host=${NACL_CROSS_PREFIX}
  if [ ${NACL_ARCH} = "pnacl" ]; then
    # The PNaCl tools use "pnacl-" as the prefix, but config.sub
    # does not know about "pnacl".  It only knows about "le32-nacl".
    # Unfortunately, most of the config.subs here are so old that
    # it doesn't know about that "le32" either.  So we just say "nacl".
    conf_host="nacl"
  fi

  BUILD_DIR=${BUILD_DIR}-test
  MakeDir ${BUILD_DIR}
  ChangeDir ${BUILD_DIR}

  LIBS="$LDFLAGS" LogExecute ../test/configure \
    --host=${conf_host} \
    --disable-assembly \
    --disable-pthread-sem \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    --oldincludedir=${NACLPORTS_INCLUDE}
}


ConfigureStep() {
  AutogenStep

  SetupCrossEnvironment

  local conf_host=${NACL_CROSS_PREFIX}
  if [ ${NACL_ARCH} = "pnacl" ]; then
    # The PNaCl tools use "pnacl-" as the prefix, but config.sub
    # does not know about "pnacl".  It only knows about "le32-nacl".
    # Unfortunately, most of the config.subs here are so old that
    # it doesn't know about that "le32" either.  So we just say "nacl".
    conf_host="nacl-pnacl"
  fi

  LogExecute ../configure \
    --host=${conf_host} \
    --disable-assembly \
    --disable-pthread-sem \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    --oldincludedir=${NACLPORTS_INCLUDE}
}


InstallTests() {
  local PUBLISH_DIR=${NACL_PACKAGES_PUBLISH}/sdl-tests/${NACL_ARCH}-${NACL_LIBC}
  Remove ${PUBLISH_DIR}
  MakeDir ${PUBLISH_DIR}
  LogExecute cp *.?exe ${PUBLISH_DIR}
  cd ../test
  LogExecute cp *.bmp *.wav *.xbm *.dat *.txt ${PUBLISH_DIR}
  ChangeDir ${PUBLISH_DIR}
  # Older versions of the SDK don't include create_html.py so we
  # need to check for its existence.
  if [ -e "${NACL_SDK_ROOT}/tools/create_html.py" ]; then
    for NEXE in *.?exe; do
      LogExecute "${NACL_SDK_ROOT}/tools/create_html.py" ${NEXE}
    done
  fi
}


PackageInstall() {
  RunPreInstallStep
  RunDownloadStep
  RunExtractStep
  RunPatchStep
  RunConfigureStep
  RunBuildStep
  RunInstallStep
  ConfigureTests
  RunBuildStep
  InstallTests
}
