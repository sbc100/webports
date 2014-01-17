#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="toybox"

# Toybox wants to build in its current directory.
BUILD_DIR=${SRC_DIR}

NACLPORTS_CFLAGS+=" -DBYTE_ORDER=LITTLE_ENDIAN"
NACLPORTS_CFLAGS+=" -I${NACLPORTS_INCLUDE}/nacl-spawn"
NACLPORTS_CXXFLAGS+=" -DBYTE_ORDER=LITTLE_ENDIAN"
NACLPORTS_CXXFLAGS+=" -I${NACLPORTS_INCLUDE}/nacl-spawn"
NACL_CONFIGURE_PATH="sh ${SRC_DIR}/configure"
export HOSTCC=cc

if [ "${NACL_GLIBC}" != "1" ]; then
  # Toybox includes and defines some items that are not available, so rather
  # than passing positive __GLIBC__ we pass positive __NEWLIB__ to identify
  # which features to decline/accept.
  NACLPORTS_CFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat -D__NEWLIB__"
  NACLPORTS_CXXFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat -D__NEWLIB__"
fi

ConfigureStep() {
  LogExecute cp ${START_DIR}/toybox.config \
    ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/.config
  LogExecute chmod +x ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/configure
  DefaultConfigureStep
}

BuildStep() {
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    export CROSS_COMPILE="pnacl-"
  else
    export CROSS_COMPILE="${NACL_ARCH}-nacl-"
  fi

  export CROSS_COMPILE="${NACL_CROSS_PREFIX}-"
  export LDFLAGS="${LDFLAGS} -lnacl_spawn -lppapi_simple -lnacl_io -lppapi"
  export LDFLAGS="${LDFLAGS} -lppapi_cpp"

  # We can't use NACL_CROSS_PREFIX without also redefining the CC and HOSTCC
  # variables.
  if [[ "${NACLCXX}" = *clang++ ]]; then
    export CC=clang++
  else
    export CC=gcc
    export LDFLAGS="${LDFLAGS} -l${NACL_CPP_LIB}"
  fi

  make clean
  DefaultBuildStep
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/toybox"
  local OUTPUT_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  MakeDir ${ASSEMBLY_DIR}

  cp ${OUTPUT_DIR}/toybox ${ASSEMBLY_DIR}/toybox_${NACL_ARCH}${NACL_EXEEXT}

  ChangeDir ${ASSEMBLY_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${ASSEMBLY_DIR}/toybox_*${NACL_EXEEXT} \
      -s . \
      -o toybox.nmf
  LogExecute python ${TOOLS_DIR}/create_term.py toybox.nmf

  InstallNaClTerm ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
  ChangeDir ${PUBLISH_DIR}
  LogExecute zip -r toybox-0.4.7.zip toybox
}
