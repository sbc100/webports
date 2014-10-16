# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


EXTRA_CONFIGURE_ARGS="--with-curses"
EXTRA_CONFIGURE_ARGS+=" --with-installed-readline --enable-readline"
NACLPORTS_CPPFLAGS+=" -DHAVE_GETHOSTNAME -DNO_MAIN_ENV_ARG"
NACLPORTS_CPPFLAGS+=" -Dmain=nacl_main"
export LIBS+="${NACL_CLI_MAIN_LIB} \
-lppapi_simple -lnacl_spawn -lnacl_io -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"

# Configure requires this variable to be pre-set when cross compiling.
export bash_cv_getcwd_malloc=yes

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  export LIBS+=" -lglibc-compat"
fi

PatchStep() {
  DefaultPatchStep
  ChangeDir ${SRC_DIR}
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  local ASSEMBLY_DIR="${PUBLISH_DIR}/bash"

  local platform_dir="${ASSEMBLY_DIR}/_platform_specific/${NACL_ARCH}"
  MakeDir ${platform_dir}
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    # Add something to the per-arch directory there so the store will accept
    # the app even if nothing else ends up there. This currently happens in
    # the pnacl case, where there's nothing that's per architecture.
    touch ${platform_dir}/MARKER

    local exe="${ASSEMBLY_DIR}/bash${NACL_EXEEXT}"
    LogExecute ${PNACLFINALIZE} ${BUILD_DIR}/bash${NACL_EXEEXT} -o ${exe}
    ChangeDir ${ASSEMBLY_DIR}
    LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
        ${exe} -s . -o bash.nmf
  else
    local exe="${platform_dir}/bash${NACL_EXEEXT}"
    LogExecute cp ${BUILD_DIR}/bash${NACL_EXEEXT} ${exe}
    ChangeDir ${ASSEMBLY_DIR}
    LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
        _platform_specific/*/bash*${NACL_EXEEXT} \
        -s . -o bash.nmf
  fi
}
