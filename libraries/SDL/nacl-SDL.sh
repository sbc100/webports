#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-SDL-1.2.14.sh
#
# usage:  nacl-SDL-1.2.14.sh
#
# this script downloads, patches, and builds SDL for Native Client
#

source pkg_info
source ../../build_tools/common.sh

AutogenStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  # For some reason if we don't remove configure before running
  # autoconf it doesn't always get updates correctly.  About half
  # the time the old configure script (with no reference to nacl)
  # will remain after ./autogen.sh
  rm configure
  ./autogen.sh
  PatchConfigure
  PatchConfigSub
}


ConfigureTests() {
  Banner "Configuring ${PACKAGE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}

  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export PATH=${NACL_BIN_PATH}:${PATH};

  local conf_host=${NACL_CROSS_PREFIX}
  if [ ${NACL_ARCH} = "pnacl" ]; then
    # The PNaCl tools use "pnacl-" as the prefix, but config.sub
    # does not know about "pnacl".  It only knows about "le32-nacl".
    # Unfortunately, most of the config.subs here are so old that
    # it doesn't know about that "le32" either.  So we just say "nacl".
    conf_host="nacl"
  fi

  Remove ${NACL_BUILD_SUBDIR}-test
  MakeDir ${NACL_BUILD_SUBDIR}-test
  cd ${NACL_BUILD_SUBDIR}-test

  LIBS="$LDFLAGS" LogExecute ../test/configure \
    --host=${conf_host} \
    --disable-assembly \
    --disable-pthread-sem \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    --oldincludedir=${NACLPORTS_INCLUDE}
}


CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}

  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export PATH=${NACL_BIN_PATH}:${PATH};

  local conf_host=${NACL_CROSS_PREFIX}
  if [ ${NACL_ARCH} = "pnacl" ]; then
    # The PNaCl tools use "pnacl-" as the prefix, but config.sub
    # does not know about "pnacl".  It only knows about "le32-nacl".
    # Unfortunately, most of the config.subs here are so old that
    # it doesn't know about that "le32" either.  So we just say "nacl".
    conf_host="nacl-pnacl"
  fi

  Remove ${NACL_BUILD_SUBDIR}
  MakeDir ${NACL_BUILD_SUBDIR}
  cd ${NACL_BUILD_SUBDIR}

  LogExecute ../configure \
    --host=${conf_host} \
    --disable-assembly \
    --disable-pthread-sem \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    --oldincludedir=${NACLPORTS_INCLUDE}
}


PublishStep() {
  local PUBLISH_DIR=${NACL_PACKAGES_PUBLISH}/sdl-tests/${NACL_ARCH}-${NACL_LIBC}
  Banner "Publishing Tests ${PUBLISH_DIR}"
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


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  AutogenStep
  CustomConfigureStep
  DefaultBuildStep
  DefaultInstallStep
  ConfigureTests
  DefaultBuildStep
  PublishStep
  DefaultCleanUpStep
}


CustomPackageInstall
exit 0
