# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

PatchStep() {
  DefaultPatchStep
  MakeDir ${SRC_DIR}/toolchain_build/src
  Remove ${SRC_DIR}/toolchain_build/src/llvm
  LogExecute ln -fs ${SRC_DIR}/../../pnacl-llvm-src/llvm \
    ${SRC_DIR}/toolchain_build/src/llvm
  Remove ${SRC_DIR}/toolchain_build/src/binutils
  LogExecute ln -fs ${SRC_DIR}/../../pnacl-binutils-src/binutils \
    ${SRC_DIR}/toolchain_build/src/binutils
  Remove ${SRC_DIR}/toolchain_build/src/clang
  LogExecute ln -fs ${SRC_DIR}/../../pnacl-clang-src/clang \
    ${SRC_DIR}/toolchain_build/src/clang
  Remove ${SRC_DIR}/toolchain_build/src/llvm/tools/clang
  LogExecute ln -fs ${SRC_DIR}/../../pnacl-clang-src/clang \
    ${SRC_DIR}/toolchain_build/src/llvm/tools/clang
}

ConfigureStep() {
  return
}

BuildStep() {
  PNACL_DIR=${NACL_SDK_ROOT}/toolchain/linux_pnacl
  export PATH=${PNACL_DIR}/bin:${PATH}
  export LD_LIBRARY_PATH=${PNACL_DIR}/lib:${LD_LIBRARY_PATH:-}
  export BUILD_CC=clang
  export BUILD_CXX=clang++

  export STRIPPROG=echo

  export HOST_OS=NativeClient
  export KEEP_SYMBOLS=1

  export GOLD_LDADD="--with-gold-ldadd="
  GOLD_LDADD+=" -Wl,--undefined=LLVMgold_onload"
  GOLD_LDADD+=" -L%(abs_llvm_le32_nacl)s/lib"
  # TODO(bradnelson): Apply llvm-config to pick this list.
  GOLD_LDADD+=" -Wl,--start-group"
  GOLD_LDADD+=" -lLLVMgold -lLLVMCodeGen -lLTO -lLLVMX86Disassembler"
  GOLD_LDADD+=" -lLLVMX86AsmParser -lLLVMX86CodeGen -lLLVMX86Desc"
  GOLD_LDADD+=" -lLLVMX86Info -lLLVMX86AsmPrinter -lLLVMX86Utils"
  GOLD_LDADD+=" -lLLVMARMDisassembler -lLLVMARMCodeGen"
  GOLD_LDADD+=" -lLLVMNaClTransforms"
  GOLD_LDADD+=" -lLLVMARMAsmParser -lLLVMARMDesc -lLLVMARMInfo"
  GOLD_LDADD+=" -lLLVMARMAsmPrinter -lLLVMMipsDisassembler -lLLVMMipsCodeGen"
  GOLD_LDADD+=" -lLLVMSelectionDAG -lLLVMAsmPrinter -lLLVMCodeGen"
  GOLD_LDADD+=" -lLLVMMipsAsmParser -lLLVMMipsDesc -lLLVMMipsInfo"
  GOLD_LDADD+=" -lLLVMMipsAsmPrinter -lLLVMMCDisassembler -lLLVMLTO"
  GOLD_LDADD+=" -lLLVMMCParser -lLLVMLinker -lLLVMipo -lLLVMObjCARCOpts"
  GOLD_LDADD+=" -lLLVMVectorize -lLLVMScalarOpts -lLLVMInstCombine"
  GOLD_LDADD+=" -lLLVMJSBackendCodeGen -lLLVMJSBackendDesc -lLLVMJSBackendInfo"
  GOLD_LDADD+=" -lLLVMTransformUtils -lLLVMipa -lLLVMBitWriter"
  GOLD_LDADD+=" -lLLVMBitReader -lLLVMAnalysis -lLLVMTarget -lLLVMMC"
  GOLD_LDADD+=" -lLLVMObject -lLLVMCore -lLLVMSupport"
  GOLD_LDADD+=" -Wl,--end-group"

  export EXTRA_CONFIGURE=""
  EXTRA_CONFIGURE+=" --extra-configure-arg=ac_cv_func_vfork_works=no"
  EXTRA_CONFIGURE+=" --extra-configure-arg=--disable-compiler-version-checks"
  EXTRA_CONFIGURE+=" --extra-configure-arg=--enable-libcpp"

  export EXTRA_CC_ARGS=""
  # Some code in llvm uses intrisics not supported in the pnacl stable abi.
  EXTRA_CC_ARGS+=" --pnacl-disable-abi-check"
  LINUX_PNACL=${NACL_SDK_ROOT}/toolchain/linux_pnacl
  USR_LOCAL=${LINUX_PNACL}/le32-nacl/usr
  EXTRA_CC_ARGS+=" -Dmain=nacl_main"
  EXTRA_CC_ARGS+=" -include nacl_main.h"
  EXTRA_CC_ARGS+=" -include spawn.h"
  EXTRA_CC_ARGS+=" -I${USR_LOCAL}/include/glibc-compat"
  EXTRA_CC_ARGS+=" -I${NACL_SDK_ROOT}/include"
  EXTRA_CC_ARGS+=" -I${USR_LOCAL}/include"
  EXTRA_CC_ARGS+=" -L${NACL_SDK_ROOT}/lib/pnacl/Release"
  EXTRA_CC_ARGS+=" -L${USR_LOCAL}/lib"
  EXTRA_CC_ARGS+=" -Wl,--undefined=PSUserCreateInstance"
  EXTRA_CC_ARGS+=" -Wl,--undefined=nacl_main"
  EXTRA_CC_ARGS+=" -Wl,--undefined=waitpid"
  EXTRA_CC_ARGS+=" -Wl,--undefined=spawnve"
  EXTRA_CC_ARGS+=" -pthread"
  EXTRA_CC_ARGS+=" ${NACL_CLI_MAIN_LIB} -lppapi_simple"
  EXTRA_CC_ARGS+=" -lnacl_io -lppapi_cpp -lppapi"
  EXTRA_CC_ARGS+=" -l${NACL_CXX_LIB} -lm -lglibc-compat"

  LogExecute ${SRC_DIR}/toolchain_build/toolchain_build_pnacl.py -v \
    --no-use-cached-results \
    --no-use-remote-cache \
    --no-annotator \
    --pnacl-in-pnacl \
    "--extra-cc-args=${EXTRA_CC_ARGS}" \
    ${EXTRA_CONFIGURE} \
    "--binutils-pnacl-extra-configure=${GOLD_LDADD}"

  rm -rf ${BUILD_DIR}/*
  LogExecute cp \
    ${SRC_DIR}/toolchain_build/out/llvm_le32_nacl_install/bin/* \
    ${BUILD_DIR}/
  LogExecute cp \
    ${SRC_DIR}/toolchain_build/out/binutils_pnacl_le32_nacl_install/bin/* \
    ${BUILD_DIR}/
  # TODO(bradnelson): Drop this once shell script fix is done.
  MakeDir ${BUILD_DIR}/driver
  LogExecute cp ${SRC_DIR}/pnacl/driver/redirect.sh ${BUILD_DIR}/driver/
  LogExecute cp ${SRC_DIR}/pnacl/driver/*.py ${BUILD_DIR}/driver/
}

InstallArch() {
  local arch=$1

  local ASSEMBLY_DIR=${PUBLISH_DIR}/${arch}
  Remove ${ASSEMBLY_DIR}/
  MakeDir ${ASSEMBLY_DIR}/
  ChangeDir ${ASSEMBLY_DIR}/

  LogExecute cp -r ${NACL_SDK_ROOT}/examples ${ASSEMBLY_DIR}/
  LogExecute cp -r ${NACL_SDK_ROOT}/getting_started ${ASSEMBLY_DIR}/
  LogExecute cp -r ${NACL_SDK_ROOT}/include ${ASSEMBLY_DIR}/
  LogExecute cp -r ${NACL_SDK_ROOT}/src ${ASSEMBLY_DIR}/

  for f in AUTHORS COPYING LICENSE NOTICE README README.Makefiles; do
    LogExecute cp ${NACL_SDK_ROOT}/${f} ${ASSEMBLY_DIR}/
  done

  MakeDir ${ASSEMBLY_DIR}/lib
  LogExecute cp -r ${NACL_SDK_ROOT}/lib/pnacl ${ASSEMBLY_DIR}/lib/

  LogExecute cp -r ${NACL_SDK_ROOT}/tools ${ASSEMBLY_DIR}/

  MakeDir ${ASSEMBLY_DIR}/toolchain
  LogExecute cp -r ${NACL_SDK_ROOT}/toolchain/linux_pnacl \
    ${ASSEMBLY_DIR}/toolchain

  # Drop pyc files.
  LogExecute find ${ASSEMBLY_DIR} -name "*.pyc" -exec rm {} \;

  # TODO(bradnelson): Drop this once shell script fix is done.
  LogExecute cp \
    ${BUILD_DIR}/driver/*.py \
    ${ASSEMBLY_DIR}/toolchain/linux_pnacl/bin/pydir/

  # Swap in nacl executables.
  for f in $(find ${ASSEMBLY_DIR} -executable -type f); do
    if [ "$(file ${f} | grep ELF)" != "" ]; then
      LogExecute rm -f ${f}
      local pexe="${BUILD_DIR}/$(basename ${f})"
      if [ -f "${pexe}" ]; then
        echo hi
        LogExecute "${TRANSLATOR}" \
          -O2 -arch "${arch}" --allow-llvm-bitcode-input \
          -ffunction-sections --gc-sections \
          "${pexe}" \
          -o "${f}"
      else
        echo "Warning: dropping ${f} without a nacl replacement."
      fi
    elif [ "$(head -n 1 ${f} | grep /bin/sh)" != "" ]; then
      # TODO(bradnelson): Drop this once shell script fix is done.
      LogExecute cp -f ${BUILD_DIR}/driver/redirect.sh ${f}
      LogExecute chmod a+x ${f}
    fi
  done

  LogExecute zip -rq ${PUBLISH_DIR}/${arch}.zip .
}

InstallStep() {
  local ARCH_LIST="arm i686 x86_64"
  for arch in ${ARCH_LIST}; do
    InstallArch ${arch}
  done
}
