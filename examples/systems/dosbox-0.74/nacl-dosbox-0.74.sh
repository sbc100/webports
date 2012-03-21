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

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/dosbox-0.74.tar.gz
#readonly URL=http://sourceforge.net/projects/dosbox/files/dosbox/0.74/dosbox-0.74.tar.gz/download
readonly PATCH_FILE=nacl-dosbox-0.74.patch
PACKAGE_NAME=dosbox-0.74

source ../../../build_tools/common.sh

DOSBOX_EXAMPLE_DIR=${NACL_SRC}/examples/systems/dosbox-0.74

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"

  if [ "${NACL_GLIBC}" = "1" ]; then
    echo "Only linker wrapping for newlib is supported"
    exit -1
  fi

  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  # NOTE: non-standard flag NACL_LDFLAGS because of some more hacking below
  export CXXFLAGS="-O2 -g"
  export NACL_LDFLAGS=""
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACL_SDK_USR_LIB}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACL_SDK_USR_LIB}

  export LIBS="-L${NACL_SDK_USR_LIB} \
      -lm \
      -lpng \
      -lz"

  CONFIG_FLAGS="--host=${CROSS_ID}-pc-nacl \
      --prefix=${NACL_SDK_USR} \
      --exec-prefix=${NACL_SDK_USR} \
      --libdir=${NACL_SDK_USR_LIB} \
      --oldincludedir=${NACL_SDK_USR_INCLUDE} \
      --with-sdl-prefix=${NACL_SDK_USR} \
      --with-sdl-exec-prefix=${NACL_SDK_USR}"

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
  LDFLAGS="${NACL_LDFLAGS} -Wl,--wrap,open \
      -Wl,--wrap,close \
      -Wl,--wrap,read \
      -Wl,--wrap,write \
      -Wl,--wrap,lseek \
      -Wl,--wrap,mkdir \
      -Wl,--wrap,rmdir \
      -Wl,--wrap,getcwd \
      -Wl,--wrap,chdir \
      -Wl,--wrap,stat \
      -Wl,--wrap,fstat \
      -Wl,--wrap,access \
      -Wl,--wrap,ioctl \
      -Wl,--wrap,link \
      -Wl,--wrap,kill \
      -Wl,--wrap,unlink \
      -Wl,--wrap,signal"

  local MAYBE_NOSYS=""
  if [ "${NACL_GLIBC}" = "0" ]; then
    MAYBE_NOSYS="-lnosys"
  fi

  SED_PREPEND_LIBS="s|^LIBS = \(.*$\)|LIBS = ${PPAPI_LIBS} \1 ${MAYBE_NOSYS}|"
  SED_REPLACE_LDFLAGS="s|^LDFLAGS = .*$|LDFLAGS = ${LDFLAGS}|"

  find . -name Makefile -exec cp {} {}.bak \; \
      -exec sed --in-place "${SED_PREPEND_LIBS}" {} \; \
      -exec sed --in-place "${SED_REPLACE_LDFLAGS}" {} \;
}

CustomInstallStep(){
  DOSBOX_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  DOSBOX_BUILD=${DOSBOX_DIR}/${PACKAGE_NAME}-build
  PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}
  install ${START_DIR}/dosbox.html ${PUBLISH_DIR}
  install ${START_DIR}/dosbox.nmf ${PUBLISH_DIR}
  install ${DOSBOX_BUILD}/src/dosbox \
      ${PUBLISH_DIR}/dosbox_x86-${NACL_PACKAGES_BITSIZE}.nexe
  DefaultTouchStep
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  if [ ${NACL_PACKAGES_BITSIZE} == "pnacl" ] ; then
    DefaultTranslateStep ${PACKAGE_NAME} ${PACKAGE_NAME}-build/src/dosbox
  fi
  CustomInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
