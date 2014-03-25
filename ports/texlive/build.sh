#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXTRA_CONFIGURE_ARGS="--prefix= --exec-prefix="
EXTRA_CONFIGURE_ARGS="${EXTRA_CONFIGURE_ARGS} \
                      --disable-native-texlive-build \
                      --enable-build-in-source-tree \
                      --disable-shared \
                      --disable-lcdf-typetools \
                      --disable-largefile \
                      --without-luatex \
                      --enable-mktextex-default \
                      --without-x \
                      --without-system-freetype \
                      --without-system-freetype2 \
                      --without-system-gd \
                      --without-system-graphite \
                      --without-system-icu \
                      --without-system-kpathsea \
                      --without-system-ptexenc \
                      --without-system-t1lib \
                      --without-system-teckit \
                      --without-system-xpdf"

NACLPORTS_LDFLAGS="${NACLPORTS_LDFLAGS} -Wl,--as-needed"
BUILD_DIR=${SRC_DIR}

ConfigureStep() {
  # TODO(phosek): we should be able to run reautoconf at this point, but
  # this requires automake > 1.12 which is not currently shipped in Ubuntu
  #${SRC_DIR}/reautoconf

  local build_host=$(${SRC_DIR}/build-aux/config.guess)
  EXTRA_CONFIGURE_ARGS+=" --build=${build_host}"

  export LIBS="-ltar -lppapi_simple -lnacl_io \
    -lppapi_cpp -lppapi -l${NACL_CPP_LIB}"
  DefaultConfigureStep
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/texlive"

  export INSTALL_TARGETS="DESTDIR=${ASSEMBLY_DIR}/texlivetar install"
  (DefaultInstallStep)

  # TODO(phosek): figure out which applications we should distribute
  local apps=()
  for file in $(find ${ASSEMBLY_DIR}/texlivetar/bin -type f); do
    if $NACLREADELF -V $file &>/dev/null; then
      apps+=($(basename $file))
    fi
  done

  ChangeDir ${ASSEMBLY_DIR}/texlivetar
  for app in "${apps[@]}"; do
    cp bin/${app} ../${app}_${NACL_ARCH}${NACL_EXEEXT}
  done
  rm -rf bin
  rm -rf include
  rm -rf share/man
  rm -rf usr
  tar cf ${ASSEMBLY_DIR}/texlive.tar .
  rm -rf ${ASSEMBLY_DIR}/texlivetar
  cd ${ASSEMBLY_DIR}
  for app in "${apps[@]}"; do
    LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
        ${app}_*${NACL_EXEEXT} \
        -s . \
        -o ${app}.nmf
    LogExecute python ${TOOLS_DIR}/create_term.py ${app}.nmf
  done

  InstallNaClTerm ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/background.js ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
  ChangeDir ${PUBLISH_DIR}
  LogExecute zip -r texlive-2013.zip texlive
}
