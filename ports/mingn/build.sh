#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BuildStep() {
  # Nothing to build.
  return
}

CreateMingnPackage() {
  local package_name="$1.${2:-${NACL_ARCH}}"
  local stamp=\"$(date)\"
  mkdir -p mingn/stamp
  echo INSTALLED=${stamp} > mingn/stamp/${package_name}
  mkdir -p ${PUBLISH_DIR}/tarballs
  tar -cvf ${PUBLISH_DIR}/tarballs/${package_name}.tar mingn
  mkdir -p ${PUBLISH_DIR}/stamp
  echo LATEST=${stamp} > ${PUBLISH_DIR}/stamp/${package_name}
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}

  # Set up files for bootstrap.
  local BASH_DIR=$(echo ${NACL_PACKAGES_PUBLISH}/bash*/${NACL_LIBC}/bash)
  local TAR_DIR=$(echo ${NACL_PACKAGES_PUBLISH}/tar*/${NACL_LIBC})
  local VIM_DIR=$(echo ${NACL_PACKAGES_PUBLISH}/vim*/${NACL_LIBC}/vim)

  cp -fr ${BASH_DIR}/* ${PUBLISH_DIR}
  cp -fr ${TAR_DIR}/{*.{nexe,nmf},lib*} ${PUBLISH_DIR}
  # We need to put the tar archive for vim in HTTP FS to run it.
  # TODO(hamaji): Move this to the package to be installed in HTML5 FS.
  cp ${VIM_DIR}/*.tar ${PUBLISH_DIR}

  # Create another archive which contains executables.
  MakeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/${NACL_ARCH}/bin
  pushd ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/${NACL_ARCH}/bin

  local COREUTILS_DIR=$(echo ${NACL_PACKAGES_PUBLISH}/coreutils*/${NACL_LIBC})
  local BINUTILS_DIR=$(echo ${NACL_PACKAGES_PUBLISH}/binutils/${NACL_LIBC})
  local GCC_DIR=$(echo ${NACL_PACKAGES_PUBLISH}/gcc/${NACL_LIBC})

  local TOOLCHAIN_OUT_DIR=mingn/toolchain/nacl_x86_glibc
  local bin_dir=${TOOLCHAIN_OUT_DIR}/bin
  local libexec_dir=${TOOLCHAIN_OUT_DIR}/libexec/gcc/x86_64-nacl/4.4.3

  mkdir -p ${bin_dir} ${libexec_dir}
  for binary in \
      ${BASH_DIR}/*_${NACL_ARCH}.nexe \
      ${TAR_DIR}/*_${NACL_ARCH}.nexe \
      ${VIM_DIR}/*_${NACL_ARCH}.nexe \
      ${GCC_DIR}/*_${NACL_ARCH}.nexe \
      ${BINUTILS_DIR}/*_${NACL_ARCH}.nexe \
      ${COREUTILS_DIR}/*_${NACL_ARCH}.nexe \
      ; do
    name=$(basename ${binary} | sed "s/_${NACL_ARCH}.nexe//")
    if [ ${name} = "cc1" -o ${name} = "cc1plus" -o ${name} = "collect2" ]; then
      cp ${binary} ${libexec_dir}/${name}
    else
      cp ${binary} ${bin_dir}/${name}
    fi
  done

  CreateMingnPackage base

  popd

  # Create an archive which contains include files and shared objects.
  MakeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/lib
  pushd ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/lib

  # Copy files from $NACL_SDK_ROOT to the package.
  local dirs="
toolchain/${OS_SUBDIR}_x86_glibc/lib/gcc/x86_64-nacl
toolchain/${OS_SUBDIR}_x86_glibc/x86_64-nacl/lib32
toolchain/${OS_SUBDIR}_x86_glibc/x86_64-nacl/lib
toolchain/${OS_SUBDIR}_x86_glibc/x86_64-nacl/include
toolchain/${OS_SUBDIR}_x86_glibc/i686-nacl/usr/lib
toolchain/${OS_SUBDIR}_x86_glibc/x86_64-nacl/usr/lib
"
  for d in $dirs; do
    local o=$(dirname mingn/$d | sed "s/${OS_SUBDIR}_/nacl_/")
    mkdir -p $o
    if [ -d ${NACL_SDK_ROOT}/$d ]; then
      cp -r ${NACL_SDK_ROOT}/$d $o
    else
      mkdir -p mingn/$d
    fi
  done

  # Merge libraries made from native_client_sdk so that you do not
  # need to specify -L option for them.
  cp ${NACL_SDK_ROOT}/lib/glibc_x86_32/Release/* \
      ${TOOLCHAIN_OUT_DIR}/i686-nacl/usr/lib
  cp ${NACL_SDK_ROOT}/lib/glibc_x86_64/Release/* \
      ${TOOLCHAIN_OUT_DIR}/x86_64-nacl/usr/lib

  # Remove unnecessary files to reduce the size of the archive.
  rm -f ${TOOLCHAIN_OUT_DIR}/x86_64-nacl/lib/32
  rm -fr ${TOOLCHAIN_OUT_DIR}/x86_64-nacl/lib*/{gconv,libgfortran*}

  # Resolve all symlinks as nacl_io does not support symlinks.
  rm -fr /tmp/mingn-tmp.tmp
  for i in $(find mingn -type l); do
    if [ ! -d $i ]; then
      cp $i /tmp/mingn-tmp.tmp
      rm $i
      mv /tmp/mingn-tmp.tmp $i
    fi
  done

  # Remove shared objects which are symlinked after we resolve them.
  find mingn -name '*.so.*.*' -exec rm -f {} \;

  # Create libmingn.so ldscripts.
  cat <<EOF > ${TOOLCHAIN_OUT_DIR}/i686-nacl/usr/lib/libmingn.so
OUTPUT_FORMAT(elf32-i386-nacl)
GROUP(-lppapi_simple -lnacl_spawn -lnacl_io -lppapi -lppapi_cpp -lcli_main -lstdc++ -lm)
EOF
  cat <<EOF > ${TOOLCHAIN_OUT_DIR}/x86_64-nacl/usr/lib/libmingn.so
OUTPUT_FORMAT(elf64-x86-64-nacl)
GROUP(-lppapi_simple -lnacl_spawn -lnacl_io -lppapi -lppapi_cpp -lcli_main -lstdc++ -lm)
EOF

  # Modify GCC's specs file. E.g.,
  # /path/to/nacl_sdk/pepper_canary/toolchain/linux_x86_glibc
  # => /mnt/html5/mingn/toolchain/nacl_x86_glibc.
  sed -i 's@/\S*/pepper_[^/]*/toolchain/[^/]*_x86_glibc@/mnt/html5/mingn/toolchain/nacl_x86_glibc@g' \
      ${TOOLCHAIN_OUT_DIR}/lib/gcc/x86_64-nacl/4.4.3/specs

  CreateMingnPackage lib all
  popd

  # Update bash.js and bash.tar for /etc/bashrc.
  # TODO(hamaji): Stop modifying bash.tar.
  MakeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/bash
  pushd ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/bash
  tar -xvf ${BASH_DIR}/bash.tar
  mkdir -p etc
  cp ${START_DIR}/bashrc etc
  tar -cvf ${PUBLISH_DIR}/bash.tar etc share
  popd
  cp ${START_DIR}/bash.js ${PUBLISH_DIR}
}
