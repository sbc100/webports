# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BuildStep() {
  # Nothing to build.
  return
}

CreateMingnPackage() {
  local package_name="$1.${2:-${NACL_ARCH}}"
  echo "CreateMingnPackage ${package_name}"
  local stamp="$(date)"
  MakeDir mingn/stamp
  echo "INSTALLED=\"${stamp}\"" > "mingn/stamp/${package_name}"
  MakeDir ${PUBLISH_DIR}/tarballs
  LogExecute rm -f ${PUBLISH_DIR}/tarballs/${package_name}.zip
  LogExecute zip -qr ${PUBLISH_DIR}/tarballs/${package_name}.zip mingn
  MakeDir "${PUBLISH_DIR}/stamp"
  echo "LATEST=\"${stamp}\"" > "${PUBLISH_DIR}/stamp/${package_name}"
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}

  # Create another archive which contains executables.
  MakeDir ${SRC_DIR}/${NACL_ARCH}/bin
  ChangeDir ${SRC_DIR}/${NACL_ARCH}/bin

  local BINUTILS_DIR=${NACL_PACKAGES_PUBLISH}/binutils/${TOOLCHAIN}
  local GCC_DIR=${NACL_PACKAGES_PUBLISH}/gcc/${TOOLCHAIN}

  local TOOLCHAIN_OUT_DIR=mingn/toolchain/nacl_x86_glibc
  local bin_dir=${TOOLCHAIN_OUT_DIR}/bin
  local libexec_dir=${TOOLCHAIN_OUT_DIR}/libexec/gcc/x86_64-nacl/4.4.3

  MakeDir ${bin_dir}
  MakeDir ${libexec_dir}
  BINARIES="\
      ${GCC_DIR}/*_${NACL_ARCH}.nexe \
      ${BINUTILS_DIR}/*_${NACL_ARCH}.nexe"

  for binary in ${BINARIES}; do
    name=$(basename ${binary} | sed "s/_${NACL_ARCH}.nexe//")
    if [ ${name} = "cc1" -o ${name} = "cc1plus" -o ${name} = "collect2" ]; then
      LogExecute cp ${binary} ${libexec_dir}/${name}
    else
      LogExecute cp ${binary} ${bin_dir}/${name}
    fi
  done

  CreateMingnPackage base

  # Create an archive which contains include files and shared objects.
  MakeDir ${SRC_DIR}/lib
  ChangeDir ${SRC_DIR}/lib

  # Copy files from $NACL_SDK_ROOT to the package.
  local dirs="
toolchain/${OS_SUBDIR}_x86_glibc/lib/gcc/x86_64-nacl
toolchain/${OS_SUBDIR}_x86_glibc/x86_64-nacl/lib32
toolchain/${OS_SUBDIR}_x86_glibc/x86_64-nacl/lib
toolchain/${OS_SUBDIR}_x86_glibc/x86_64-nacl/include
"
  for d in ${dirs}; do
    local o=$(echo mingn/${d} | sed "s/${OS_SUBDIR}_/nacl_/")
    echo "Copying libs from: ${d} -> ${o}"
    MakeDir ${o}
    if [ -d ${NACL_SDK_ROOT}/${d} ]; then
      cp -R ${NACL_SDK_ROOT}/${d} $(dirname ${o})
    else
      MakeDir ${o}
    fi
  done

  # Remove unnecessary files to reduce the size of the archive.
  LogExecute rm -f ${TOOLCHAIN_OUT_DIR}/x86_64-nacl/lib/32
  LogExecute rm -fr ${TOOLCHAIN_OUT_DIR}/x86_64-nacl/lib*/{gconv,libgfortran*}

  # Resolve all symlinks as nacl_io does not support symlinks.
  for i in $(find mingn -type l); do
    if [ ! -d ${i} ]; then
      cp ${i} ${i}.tmp
      rm ${i}
      mv ${i}.tmp ${i}
    fi
  done

  # Create a directory for additional libraries.
  for arch in i686 x86_64; do
    local usr_lib_dir=${TOOLCHAIN_OUT_DIR}/${arch}-nacl/usr/lib
    local usr_lib_ports=${NACL_TOOLCHAIN_ROOT}/${arch}-nacl/usr/lib

    mkdir -p ${usr_lib_dir}
    mkdir -p ${usr_lib_dir}/debug

    # Copy libz, libncurses, libnacl-spawn, and libcli_main.
    if ! cp -f \
        ${usr_lib_ports}/libz.so* \
        ${usr_lib_ports}/libncurses.so* \
        ${usr_lib_ports}/libcli_main.a \
        ${usr_lib_ports}/libnacl_spawn.* \
        ${usr_lib_dir}; then
      # They may not exist when we are building only for a single arch.
      if [ ${NACL_ARCH} = ${arch} ]; then
        echo "Failed to copy ${usr_lib_ports}"
        exit 1
      fi
    fi

    local arch_alt=${arch}
    if [ ${arch_alt} = "i686" ]; then
      arch_alt="x86_32"
      local ld_format="elf32-i386-nacl"
    else
      local ld_format="elf64-x86-64-nacl"
    fi

    # Merge libraries made from native_client_sdk so that you do not
    # need to specify -L option for them.
    cp ${NACL_SDK_ROOT}/lib/glibc_${arch_alt}/Release/* ${usr_lib_dir}
    # But also copy the debug ones.
    cp ${NACL_SDK_ROOT}/lib/glibc_${arch_alt}/Debug/* ${usr_lib_dir}/debug

    local mingn_ldflags="${NACL_CLI_MAIN_LIB} -lppapi_simple -lnacl_io"
    mingn_ldflags+=" -lppapi -lppapi_cpp -lstdc++ -lm"
    # Create libmingn.so ldscripts.
    cat <<EOF > ${TOOLCHAIN_OUT_DIR}/${arch}-nacl/usr/lib/libmingn.so
OUTPUT_FORMAT(${ld_format})
GROUP(${mingn_ldflags})
EOF
  done

  # Copy in SDK includes.
  LogExecute cp -r ${NACL_SDK_ROOT}/include mingn/

  # Remove shared objects which are symlinked after we resolve them.
  find mingn -name '*.so.*.*' -exec rm -f {} \;

  # Modify GCC's specs file. E.g.,
  # /path/to/nacl_sdk/pepper_canary/toolchain/linux_x86_glibc
  # => /mnt/html5/mingn/toolchain/nacl_x86_glibc.
  sed -i.bak 's@/\S*/pepper_[^/]*/toolchain/[^/]*_x86_glibc@/mnt/html5/mingn/toolchain/nacl_x86_glibc@g' \
      ${TOOLCHAIN_OUT_DIR}/lib/gcc/x86_64-nacl/4.4.3/specs

  CreateMingnPackage lib all
}
