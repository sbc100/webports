#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../../build_tools/common.sh

export EXTRA_LIBS="-ltar -lppapi_simple -lnacl_io -lppapi -lppapi_cpp"

PatchStep() {
  DefaultPatchStep
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  cp ${START_DIR}/vim_pepper.c src/vim_pepper.c
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
  export NACL_BUILD_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  export NACL_CONFIGURE_PATH=./configure
  DefaultConfigureStep --with-tlib=ncurses --prefix= --exec-prefix=
  # Vim's build doesn't support building outside the source tree.
  # Do a clean to make rebuild after failure predictable.
  LogExecute make clean
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/vim"

  export INSTALL_TARGETS="DESTDIR=${ASSEMBLY_DIR}/vimtar install"
  DefaultInstallStep

  ChangeDir ${ASSEMBLY_DIR}/vimtar
  cp bin/vim ../vim_${NACL_ARCH}${NACL_EXEEXT}
  rm -rf bin
  rm -rf share/man
  tar cf ${ASSEMBLY_DIR}/vim.tar .
  rm -rf ${ASSEMBLY_DIR}/vimtar
  cp ${START_DIR}/vim.html ${ASSEMBLY_DIR}
  cd ${ASSEMBLY_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${NACL_CREATE_NMF_FLAGS} \
      vim_*${NACL_EXEEXT} \
      -s . \
      -o vim.nmf

  local CHROMEAPPS=${NACL_SRC}/libraries/hterm/src/chromeapps
  local LIB_DOT=${CHROMEAPPS}/libdot
  local NASSH=${CHROMEAPPS}/nassh
  LIBDOT_SEARCH_PATH=${CHROMEAPPS} ${LIB_DOT}/bin/concat.sh \
      -i ${NASSH}/concat/nassh_deps.concat \
      -o ${ASSEMBLY_DIR}/hterm.concat.js
  LogExecute cp ${START_DIR}/*.js ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
  ChangeDir ${PUBLISH_DIR}
  LogExecute zip -r vim-7.3.zip vim
}

PackageInstall
exit 0
