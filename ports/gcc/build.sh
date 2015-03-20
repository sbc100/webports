# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export EXTRA_LIBS="${NACL_CLI_MAIN_LIB} \
  -lppapi_simple -lnacl_io -lppapi -l${NACL_CXX_LIB}"

# --with-build-sysroot is necessary to run "fixincl"
# properly. Without this option, GCC's build system tries to create
# "include-fixed" based on the host's include directory, which is
# not compatible with nacl-gcc.
EXTRA_CONFIGURE_ARGS="\
    --enable-languages=c,c++ --disable-nls \
    --target=x86_64-nacl \
    --disable-libstdcxx-pch --enable-threads=nacl"

ConfigureStep() {
  DefaultConfigureStep
  for cache_file in $(find . -name config.cache); do
    Remove $cache_file
  done
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  for nexe in gcc/xgcc gcc/g++ gcc/cpp gcc/cc1 gcc/cc1plus gcc/collect2; do
    local name=$(basename $nexe | sed 's/xgcc/gcc/')
    cp ${nexe} ${PUBLISH_DIR}/${name}_${NACL_ARCH}${NACL_EXEEXT}

    pushd ${PUBLISH_DIR}
    LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
        ${PUBLISH_DIR}/${name}_*${NACL_EXEEXT} \
        -s . \
        -o ${name}.nmf
    popd
  done
}
