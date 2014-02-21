#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES=bin/xaos
NACL_CPPFLAGS+=" -D__NO_MATH_INLINES=1"

PatchStep() {
  DefaultPatchStep
  echo "copy nacl driver"
  cp -r "${START_DIR}/nacl-ui-driver" "${SRC_DIR}/src/ui/ui-drv/nacl"
}

ConfigureStep() {
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  # NOTE: non-standard flag NACL_LDFLAGS because of some more hacking below
  export CFLAGS=${NACLPORTS_CFLAGS}
  export CPPFLAGS=${NACLPORTS_CPPFLAGS}
  export LDFLAGS="${NACLPORTS_LDFLAGS} -Wl,--undefined=PPP_GetInterface \
                  -Wl,--undefined=PPP_ShutdownModule \
                  -Wl,--undefined=PPP_InitializeModule \
                  -Wl,--undefined=original_main"
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}

  export LIBS="-L${NACLPORTS_LIBDIR} -lppapi \
    -lpthread -l${NACL_CPP_LIB} -lm"

  CONFIG_FLAGS="--with-png=no \
      --with-long-double=no \
      --host=nacl \
      --with-x11-driver=no \
      --with-sffe=no"

  ChangeDir ${SRC_DIR}

  # xaos does not work with a build dir which is separate from the
  # src dir - so we copy src -> build
  Remove ${BUILD_DIR}
  local tmp=${SRC_DIR}.tmp
  Remove ${tmp}
  cp -r ${SRC_DIR} ${tmp}
  mv ${tmp} ${BUILD_DIR}

  ChangeDir ${BUILD_DIR}
  echo "running autoconf"
  LogExecute rm ./configure
  LogExecute autoconf
  echo "Configure options: ${CONFIG_FLAGS}"
  ./configure ${CONFIG_FLAGS}
}

InstallStep(){
  MakeDir ${PUBLISH_DIR}
  install ${START_DIR}/xaos.html ${PUBLISH_DIR}
  install ${START_DIR}/xaos.nmf ${PUBLISH_DIR}
  # Not used yet
  install ${BUILD_DIR}/help/xaos.hlp ${PUBLISH_DIR}
  install ${BUILD_DIR}/bin/xaos ${PUBLISH_DIR}/xaos_${NACL_ARCH}${NACL_EXEEXT}
}
