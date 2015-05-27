# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export EXTRA_LIBS="${NACL_CLI_MAIN_LIB}"
EXECUTABLES=src/tar

# The default when cross compiling is to assume chown does not
# follow symlinks, and the code that works around this in chown.c
# does not compile under newlib (missing O_NOCTTY).
export gl_cv_func_chown_follows_symlink=yes

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  export LIBS="-lglibc-compat"
fi

if [ "${TOOLCHAIN}" = "pnacl" -o "${TOOLCHAIN}" = "clang-newlib" ]; then
  # correctly handle 'extern inline'
  NACLPORTS_CPPFLAGS+=" -std=gnu89"
fi

PublishStep() {
  MakeDir ${PUBLISH_DIR}
  cp src/tar ${PUBLISH_DIR}/tar_${NACL_ARCH}${NACL_EXEEXT}
  pushd ${PUBLISH_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${PUBLISH_DIR}/tar_*${NACL_EXEEXT} \
      -s . \
      -o tar.nmf
  popd
}
