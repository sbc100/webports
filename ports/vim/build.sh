#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}
EXTRA_CONFIGURE_ARGS="--with-tlib=ncurses --prefix= --exec-prefix="
EXECUTABLES=src/vim${NACL_EXEEXT}
export EXTRA_LIBS="${NACL_CLI_MAIN_LIB} -ltar -lppapi_simple -lnacl_io \
  -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"

PatchStep() {
  DefaultPatchStep
  LogExecute cp ${START_DIR}/vim_pepper.c ${SRC_DIR}/src/vim_pepper.c
}

ConfigureStep() {
  export vim_cv_toupper_broken=1
  export vim_cv_terminfo=yes
  export vim_cv_tty_mode=1
  export vim_cv_tty_group=1
  export vim_cv_getcwd_broken=yes
  export vim_cv_stat_ignores_slash=yes
  export vim_cv_memmove_handles_overlap=yes
  if [ "${NACL_DEBUG}" == "1" ]; then
    export STRIP=echo
  else
    export STRIP=${NACLSTRIP}
  fi
  NACL_CONFIGURE_PATH=./configure
  DefaultConfigureStep
  # Vim's build doesn't support building outside the source tree.
  # Do a clean to make rebuild after failure predictable.
  LogExecute make clean
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/vim"

  DESTDIR=${ASSEMBLY_DIR}/vimtar
  DefaultInstallStep

  ChangeDir ${ASSEMBLY_DIR}/vimtar
  cp bin/vim${NACL_EXEEXT} ../vim_${NACL_ARCH}${NACL_EXEEXT}
  rm -rf bin
  rm -rf share/man
  tar cf ${ASSEMBLY_DIR}/vim.tar .
  rm -rf ${ASSEMBLY_DIR}/vimtar
  cd ${ASSEMBLY_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      vim_*${NACL_EXEEXT} \
      -s . \
      -o vim.nmf
  LogExecute python ${TOOLS_DIR}/create_term.py vim.nmf

  InstallNaClTerm ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/background.js ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
  ChangeDir ${PUBLISH_DIR}
  LogExecute zip -r vim-7.3.zip vim
}
