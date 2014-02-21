#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

PACKAGE_DIR=${PACKAGE_NAME}-src
SRC_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
BUILD_DIR=${SRC_DIR}/${NACL_BUILD_SUBDIR}

EXECUTABLES=snes9x
NACL_CONFIGURE_PATH=${SRC_DIR}/unix/configure
EXTRA_CONFIGURE_ARGS="\
      --disable-gamepad \
      --disable-gzip \
      --disable-zip \
      --disable-jma \
      --disable-screenshot \
      --disable-netplay \
      --without-x \
      --enable-sound"
export LIBS="${NACLPORTS_LDFLAGS} -lppapi_simple -lnacl_io -lppapi_cpp -lppapi"

AutogenStep() {
  echo "Autogen..."
  pushd ${SRC_DIR}/unix
  autoconf
  PatchConfigure
  PatchConfigSub
  popd
}

ConfigureStep() {
  AutogenStep
  DefaultConfigureStep

  # This configure script generates a Makefile that checks timestamps on
  # configure.ac, configure and Makefile.in. Copy them from the unix directory.
  LogExecute cp ../unix/{configure.ac,configure,Makefile.in} .
  touch Makefile
}

InstallStep(){
  MakeDir ${PUBLISH_DIR}
  install ${START_DIR}/snes9x.html ${PUBLISH_DIR}
  install ${START_DIR}/snes9x.js ${PUBLISH_DIR}
  install ${BUILD_DIR}/snes9x ${PUBLISH_DIR}/snes9x_${NACL_ARCH}${NACL_EXEEXT}

  python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${PUBLISH_DIR}/snes9x_*${NACL_EXEEXT} \
      -s ${PUBLISH_DIR} \
      -o ${PUBLISH_DIR}/snes9x.nmf

  if [ "${NACL_ARCH}" = "pnacl" ]; then
    sed -i.bak 's/x-nacl/x-pnacl/' ${PUBLISH_DIR}/snes9x.js
  fi
}
