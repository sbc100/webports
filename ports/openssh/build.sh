#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="scp${NACL_EXEEXT} ssh${NACL_EXEEXT} \
             ssh-add${NACL_EXEEXT} sshd${NACL_EXEEXT}"
INSTALL_TARGETS="install-nokeys DESTDIR=${NACLPORTS_PREFIX}"

# Force configure to recognise the existence of truncate
# and sigaction.  Normally it will detect that both this functions
# are implemented by glibc in terms of NOSYS.
export ac_cv_func_truncate=yes
export ac_cv_func_sigaction=yes

export SSHLIBS="-lppapi_simple -lnacl_io -lppapi_cpp -lppapi"
if [ "${NACL_GLIBC}" != 1 ]; then
  CFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  export LIBS=" -lcrypto -lglibc-compat"
  export LD="${NACLCXX}"
fi

ConfigureStep() {
  # This function differs from the DefaultConfigureStep in that
  # it does not configure openssh with a --prefix.  Instead it
  # defaults to /usr and then passed DESTDIR= at make install
  # time.  Without this make install will fail as it tries
  # to write to DESTDIR/etc directly (without the prefix).

  SetupCrossEnvironment

  local conf_host=${NACL_CROSS_PREFIX}
  if [ "${NACL_ARCH}" = "pnacl" -o "${NACL_ARCH}" = "emscripten" ]; then
    # The PNaCl tools use "pnacl-" as the prefix, but config.sub
    # does not know about "pnacl".  It only knows about "le32-nacl".
    # Unfortunately, most of the config.subs here are so old that
    # it doesn't know about that "le32" either.  So we just say "nacl".
    conf_host="nacl"
  fi

  LogExecute ../configure \
    --host=${conf_host} \
    --${NACL_OPTION}-mmx \
    --${NACL_OPTION}-sse \
    --${NACL_OPTION}-sse2 \
    --${NACL_OPTION}-asm
}

InstallStep() {
  DefaultInstallStep

  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/openssh"
  MakeDir ${ASSEMBLY_DIR}
  LogExecute cp ssh${NACL_EXEEXT} \
      ${ASSEMBLY_DIR}/ssh_${NACL_ARCH}${NACL_EXEEXT}

  pushd ${ASSEMBLY_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ssh_*${NACL_EXEEXT} \
      -s . \
      -o openssh.nmf
  LogExecute python ${TOOLS_DIR}/create_term.py openssh.nmf
  popd

  InstallNaClTerm ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/background.js ${ASSEMBLY_DIR}
  LogExecute cp ${START_DIR}/manifest.json ${ASSEMBLY_DIR}
}
