# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}
EXTRA_CONFIGURE_ARGS="--with-tlib=ncurses --prefix=/usr --exec-prefix=/usr"
EXECUTABLES=src/vim${NACL_EXEEXT}
export EXTRA_LIBS="${NACL_CLI_MAIN_LIB} -ltar -lppapi_simple -lnacl_io \
  -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"

PatchStep() {
  DefaultPatchStep
  LogExecute cp ${START_DIR}/vim_pepper.c ${SRC_DIR}/src/vim_pepper.c
}

ConfigureStep() {
  # These settings are required by vim's configure when cross compiling.
  # These are the standard valued detected when configuring for linux/glibc.
  export vim_cv_toupper_broken=no
  export vim_cv_terminfo=yes
  export vim_cv_tty_mode=0620
  export vim_cv_tty_group=world
  export vim_cv_getcwd_broken=no
  export vim_cv_stat_ignores_slash=no
  export vim_cv_memmove_handles_overlap=yes
  export ac_cv_func_getrlimit=no
  if [ "${NACL_DEBUG}" == "1" ]; then
    export STRIP=echo
  else
    export STRIP=${NACLSTRIP}
  fi
  DefaultConfigureStep
  # Vim's build doesn't support building outside the source tree.
  # Do a clean to make rebuild after failure predictable.
  LogExecute make clean
}

InstallStep() {
  return
}

PublishStep() {
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/vim"

  # TODO(sbc): avoid duplicating the install step here.
  DESTDIR=${ASSEMBLY_DIR}/vimtar
  DefaultInstallStep

  ChangeDir ${ASSEMBLY_DIR}/vimtar
  cp usr/bin/vim${NACL_EXEEXT} ../vim_${NACL_ARCH}${NACL_EXEEXT}
  cp $SRC_DIR/runtime/vimrc_example.vim usr/share/vim/vimrc
  rm -rf usr/bin
  rm -rf usr/share/man
  tar cf ${ASSEMBLY_DIR}/vim.tar .
  rm -rf ${ASSEMBLY_DIR}/vimtar
  cd ${ASSEMBLY_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      vim_*${NACL_EXEEXT} \
      -s . \
      -o vim.nmf
  LogExecute python ${TOOLS_DIR}/create_term.py vim.nmf

  GenerateManifest ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
  InstallNaClTerm ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/background.js ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/vim.html ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/vim_app.html ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/vim.js ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_16.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_48.png ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/icon_128.png ${ASSEMBLY_DIR}
  ChangeDir ${PUBLISH_DIR}
  CreateWebStoreZip vim-${VERSION}.zip vim
}
