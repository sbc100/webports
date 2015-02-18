# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="scp${NACL_EXEEXT} ssh${NACL_EXEEXT} \
             ssh-add${NACL_EXEEXT} sshd${NACL_EXEEXT}"
INSTALL_TARGETS="install-nokeys"

# Add --with-privsep-path otherwise openssh creates /var/empty
# in the root of DESTDIR.
EXTRA_CONFIGURE_ARGS="--with-privsep-path=${PREFIX}/var/empty"

# Force configure to recognise the existence of truncate
# and sigaction.  Normally it will detect that both this functions
# are implemented by glibc in terms of NOSYS.
export ac_cv_func_truncate=yes
export ac_cv_func_sigaction=yes

export SSHLIBS="-lppapi_simple -lnacl_io -lnacl_spawn -lcli_main -lppapi_cpp \
-lppapi -l${NACL_CPP_LIB}"
if [ "${NACL_LIBC}" = "newlib" ]; then
  CFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  export LIBS=" -lcrypto -lglibc-compat"
  export LD="${NACLCXX}"
fi

PublishStep() {
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
