#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-dosbox-0.74.sh
#
# usage:  nacl-dosbox-0.74.sh
#
# this script downloads, patches, and builds dosbox for Native Client.
#

source pkg_info
source ../../../build_tools/common.sh

DOSBOX_EXAMPLE_DIR=${NACL_SRC}/examples/systems/dosbox-0.74

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"

  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  # NOTE: non-standard flag NACL_LDFLAGS because of some more hacking below
  export CXXFLAGS="${NACLPORTS_CFLAGS} -O2 -g -I${NACL_SDK_ROOT}/include"
  export NACL_LDFLAGS="${NACLPORTS_LDFLAGS}"
  if [ ${NACL_ARCH} = "pnacl" ] ; then
    export CXXFLAGS="${NACLPORTS_CFLAGS} -O3 -g I${NACL_SDK_ROOT}/include"
    export NACL_LDFLAGS="${NACL_LDFLAGS} -O0 -static"
  fi
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export STRIP=${NACLSTRIP}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}

  export LIBS="-L${NACLPORTS_LIBDIR} \
      -lm \
      -lpng \
      -lz"

  CONFIG_FLAGS="--host=${NACL_ARCH}-pc-nacl \
      --prefix=${NACLPORTS_PREFIX} \
      --exec-prefix=${NACLPORTS_PREFIX} \
      --libdir=${NACLPORTS_LIBDIR} \
      --oldincludedir=${NACLPORTS_INCLUDE} \
      --with-sdl-prefix=${NACLPORTS_PREFIX} \
      --with-sdl-exec-prefix=${NACLPORTS_PREFIX}"

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  ./autogen.sh

  Remove ${PACKAGE_NAME}-build
  MakeDir ${PACKAGE_NAME}-build
  cd ${PACKAGE_NAME}-build
  ../configure ${CONFIG_FLAGS}

  # TODO(clchiou): Sadly we cannot export LIBS and LDFLAGS to configure, which
  # would fail due to multiple definitions of main and missing pp::CreateModule.
  # So we patch auto-generated Makefile after running configure.
  #
  # XXX To avoid symbol conflicts after revision r490, which switches SDL video
  # driver to MainThreadRunner, move -lnacl-mounts to the end of PPAPI_LIBS.
  # This somehow works for me.
  PPAPI_LIBS="-Wl,--whole-archive \
      -lppapi \
      -lppapi_cpp \
      -lSDL \
      -lSDLmain \
      -Wl,--no-whole-archive \
      ppapi/libppapi.a \
      -lnacl-mounts"

  # linker wrappers, defined in libnacl-mounts
  LDFLAGS="${NACL_LDFLAGS}"

  local MAYBE_NOSYS=""
  if [ "${NACL_GLIBC}" = "0" ]; then
    MAYBE_NOSYS="-lnosys"
  fi

  SED_PREPEND_LIBS="s|^LIBS = \(.*$\)|LIBS = ${PPAPI_LIBS} \1 ${MAYBE_NOSYS}|"
  SED_REPLACE_LDFLAGS="s|^LDFLAGS = .*$|LDFLAGS = ${LDFLAGS}|"

  find . -name Makefile -exec cp {} {}.bak \; \
      -exec sed -i.bak "${SED_PREPEND_LIBS}" {} \; \
      -exec sed -i.bak "${SED_REPLACE_LDFLAGS}" {} \;
}

CustomInstallStep(){
  DOSBOX_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  DOSBOX_BUILD=${DOSBOX_DIR}/${PACKAGE_NAME}-build
  PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}
  install ${START_DIR}/dosbox.html ${PUBLISH_DIR}
  install ${START_DIR}/dosbox.nmf ${PUBLISH_DIR}
  install ${DOSBOX_BUILD}/src/dosbox \
      ${PUBLISH_DIR}/dosbox_${NACL_ARCH}.nexe
  DefaultTouchStep
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  if [ ${NACL_ARCH} = "pnacl" ] ; then
    DefaultTranslateStep ${PACKAGE_NAME} ${PACKAGE_NAME}-build/src/dosbox
  fi
  CustomInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
