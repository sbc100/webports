#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/pixman-1"
NACLPORTS_CPPFLAGS+=" -DFASYNC=O_NONBLOCK -DFNDELAY=O_NONBLOCK"

EXECUTABLES=hw/kdrive/sdl/Xsdl${NACL_EXEEXT}

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
fi

EXTRA_CONFIGURE_ARGS+=" --disable-glx"
EXTRA_CONFIGURE_ARGS+=" --enable-xfree86-utils=no"
EXTRA_CONFIGURE_ARGS+=" --enable-pciaccess=no"
EXTRA_CONFIGURE_ARGS+=" --enable-kdrive"
EXTRA_CONFIGURE_ARGS+=" --enable-local-transport=no"
EXTRA_CONFIGURE_ARGS+=" --enable-unix-transport=no"
EXTRA_CONFIGURE_ARGS+=" --enable-static=yes"
EXTRA_CONFIGURE_ARGS+=" --enable-shared=no"
EXTRA_CONFIGURE_ARGS+=" --enable-unit-tests=no"
EXTRA_CONFIGURE_ARGS+=" --enable-ipv6=no"
EXTRA_CONFIGURE_ARGS+=" --datarootdir=/mnt/html5/share"
EXTRA_CONFIGURE_ARGS+=" --with-xkb-bin-directory=/mnt/html5/packages/xkbcomp"

NACLPORTS_CFLAGS+=" -Dmain=SDL_main"
NACLPORTS_LDFLAGS+=" -lSDL2main"
export LIBS+=" -Wl,--undefined=SDL_main \
  -lnacl_spawn -lSDL2 -lppapi_simple \
  -lnacl_io -lppapi -lppapi_cpp -lppapi_gles2 \
  -l${NACL_CPP_LIB} -lcli_main"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  export LIBS+=" -lglibc-compat"
fi

PatchStep() {
  DefaultPatchStep
  MakeDir ${SRC_DIR}/hw/kdrive/sdl
  LogExecute cp ${START_DIR}/sdl.c \
                ${START_DIR}/Makefile.am \
                ${SRC_DIR}/hw/kdrive/sdl/
}

ConfigureStep() {
  ChangeDir ${SRC_DIR}
  autoreconf --force -v --install
  export GL_CFLAGS=" "
  export GL_LIBS="-lRegal"
  ChangeDir ${BUILD_DIR}
  DefaultConfigureStep
}

InstallStep() {
  Banner "Publishing to ${PUBLISH_DIR}"
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR=${PUBLISH_DIR}/xorg-server
  MakeDir ${ASSEMBLY_DIR}

  ChangeDir ${ASSEMBLY_DIR}
  for f in manifest.json \
           background.js \
           xorg_16.png \
           xorg_48.png \
           xorg_128.png \
           index.html; do
    LogExecute cp ${START_DIR}/${f} .
  done
  LogExecute cp ${BUILD_DIR}/hw/kdrive/sdl/Xsdl${NACL_EXEEXT} \
                ${ASSEMBLY_DIR}/Xsdl_${NACL_ARCH}${NACL_EXEEXT}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${ASSEMBLY_DIR}/Xsdl_*${NACL_EXEEXT} \
      -s . \
      -o Xsdl.nmf

  ChangeDir ${PUBLISH_DIR}
  LogExecute zip -r xorg-server.zip xorg-server
}
