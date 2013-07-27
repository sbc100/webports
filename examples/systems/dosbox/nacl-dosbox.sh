#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../../build_tools/common.sh

DOSBOX_EXAMPLE_DIR=${NACL_SRC}/examples/systems/dosbox-0.74
EXECUTABLES=src/dosbox${NACL_EXEEXT}

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"

  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  # NOTE: non-standard flag NACL_LDFLAGS because of some more hacking below
  export CXXFLAGS="${NACLPORTS_CFLAGS} -O2 -g"
  export NACL_LDFLAGS="${NACLPORTS_LDFLAGS}"
  if [ ${NACL_ARCH} = "pnacl" ] ; then
    export CXXFLAGS="${NACLPORTS_CFLAGS} -O3 -g"
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

  export LDFLAGS="$LDFLAGS -Wl,--as-needed"

  local conf_host=${NACL_CROSS_PREFIX}
  if [ ${NACL_ARCH} = "pnacl" ]; then
    # The PNaCl tools use "pnacl-" as the prefix, but config.sub
    # does not know about "pnacl".  It only knows about "le32-nacl".
    # Unfortunately, most of the config.subs here are so old that
    # it doesn't know about that "le32" either.  So we just say "nacl".
    conf_host="nacl"
  fi

  CONFIG_FLAGS="--host=${conf_host} \
      --prefix=${NACLPORTS_PREFIX} \
      --exec-prefix=${NACLPORTS_PREFIX} \
      --libdir=${NACLPORTS_LIBDIR} \
      --oldincludedir=${NACLPORTS_INCLUDE} \
      --with-sdl-prefix=${NACLPORTS_PREFIX} \
      --disable-shared \
      --with-sdl-exec-prefix=${NACLPORTS_PREFIX}"

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  ./autogen.sh

  MakeDir ${NACL_BUILD_SUBDIR}
  ChangeDir ${NACL_BUILD_SUBDIR}
  LogExecute ../configure ${CONFIG_FLAGS}

  # TODO(clchiou): Sadly we cannot export LIBS and LDFLAGS to configure, which
  # would fail due to multiple definitions of main and missing pp::CreateModule.
  # So we patch auto-generated Makefile after running configure.
  #
  # XXX To avoid symbol conflicts after revision r490, which switches SDL video
  # driver to MainThreadRunner, move -lnacl-mounts to the end of PPAPI_LIBS.
  # This somehow works for me.
  PPAPI_LIBS="-lSDL \
      -lppapi_cpp \
      -lppapi_cpp_private \
      -lppapi \
      ppapi/libppapi.a \
      -lnacl-mounts"

  # linker wrappers, defined in libnacl-mounts
  LDFLAGS="${NACL_LDFLAGS}"

  local MAYBE_NOSYS=""
  if [ "${NACL_GLIBC}" != "1" ]; then
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
  DOSBOX_BUILD=${DOSBOX_DIR}/${NACL_BUILD_SUBDIR}
  PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}
  LogExecute install ${START_DIR}/dosbox.html ${PUBLISH_DIR}
  LogExecute install ${DOSBOX_BUILD}/src/dosbox${NACL_EXEEXT} \
    ${PUBLISH_DIR}/dosbox_${NACL_ARCH}${NACL_EXEEXT}
  local CREATE_NMF="${NACL_SDK_ROOT}/tools/create_nmf.py ${NACL_CREATE_NMF_FLAGS}"
  LogExecute ${CREATE_NMF} -s ${PUBLISH_DIR} ${PUBLISH_DIR}/dosbox_*${NACL_EXEEXT} -o ${PUBLISH_DIR}/dosbox.nmf
}

CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  DefaultTranslateStep
  DefaultValidateStep
  CustomInstallStep
}

CustomPackageInstall
exit 0
