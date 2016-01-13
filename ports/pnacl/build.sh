# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="arm-nacl-readelf le32-nacl-strings clang clang++"

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

  GOLD_LDADD="--with-gold-ldadd="
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

  EXTRA_CONFIGURE="--extra-configure-arg=ac_cv_func_vfork_works=no"
  EXTRA_CONFIGURE+=" --extra-configure-arg=--disable-compiler-version-checks"
  EXTRA_CONFIGURE+=" --extra-configure-arg=--enable-libcpp"

  # Some code in llvm uses intrisics not supported in the pnacl stable abi.
  EXTRA_CC_ARGS="-fgnu-inline-asm"
  EXTRA_CC_ARGS+=" --pnacl-disable-abi-check"
  LINUX_PNACL=${NACL_SDK_ROOT}/toolchain/linux_pnacl
  USR_LOCAL=${LINUX_PNACL}/le32-nacl/usr
  EXTRA_CC_ARGS+=" -include spawn.h"
  EXTRA_CC_ARGS+=" -I${USR_LOCAL}/include/glibc-compat"
  EXTRA_CC_ARGS+=" -I${NACL_SDK_ROOT}/include"
  EXTRA_CC_ARGS+=" -I${USR_LOCAL}/include"
  EXTRA_CC_ARGS+=" -L${NACL_SDK_ROOT}/lib/pnacl/Release"
  EXTRA_CC_ARGS+=" -L${USR_LOCAL}/lib"
  EXTRA_CC_ARGS+=" -pthread"
  EXTRA_CC_ARGS+=" ${NACL_CLI_MAIN_LDFLAGS}"
  EXTRA_CC_ARGS+=" -lglibc-compat ${NACL_CLI_MAIN_LIB_CPP}"

  export GOLD_LDADD
  export EXTRA_CONFIGURE
  export EXTRA_CC_ARGS
  LogExecute ${SRC_DIR}/toolchain_build/toolchain_build_pnacl.py -v \
    --no-use-cached-results \
    --no-use-remote-cache \
    --no-annotator \
    --pnacl-in-pnacl \
    "--extra-cc-args=${EXTRA_CC_ARGS}" \
    ${EXTRA_CONFIGURE} \
    "--binutils-pnacl-extra-configure=${GOLD_LDADD}"

  Remove ${BUILD_DIR}
  MakeDir ${BUILD_DIR}
  LogExecute cp \
    ${SRC_DIR}/toolchain_build/out/llvm_le32_nacl_install/bin/* ${BUILD_DIR}/
  LogExecute cp \
    ${SRC_DIR}/toolchain_build/out/binutils_pnacl_le32_nacl_install/bin/* \
    ${BUILD_DIR}/
  # TODO(bradnelson): Drop this once shell script fix is done.
  MakeDir ${BUILD_DIR}/driver
  LogExecute cp ${SRC_DIR}/pnacl/driver/redirect.sh ${BUILD_DIR}/driver/
  LogExecute cp ${SRC_DIR}/pnacl/driver/*.py ${BUILD_DIR}/driver/
}

InstallStep() {
  local ASSEMBLY_DIR=${DESTDIR}/${PREFIX}/pnacl
  Remove ${ASSEMBLY_DIR}/
  MakeDir ${ASSEMBLY_DIR}/

  LogExecute cp -r ${NACL_SDK_ROOT}/toolchain/linux_pnacl/* ${ASSEMBLY_DIR}

  # Drop pyc files.
  LogExecute find ${ASSEMBLY_DIR} -name "*.pyc" -exec rm {} \;

  # TODO(bradnelson): Drop this once shell script fix is done.
  LogExecute cp ${BUILD_DIR}/driver/*.py ${ASSEMBLY_DIR}/bin/pydir/

  # Swap in nacl executables.
  Remove ${ASSEMBLY_DIR}/lib/*.so
  for f in $(find ${ASSEMBLY_DIR} -executable -type f); do
    if [ "$(file ${f} | grep ELF)" != "" ]; then
      local pexe="${BUILD_DIR}/$(basename ${f})"
      if [ -f "${pexe}" ]; then
        LogExecute ${PNACLFINALIZE} ${pexe} -o ${f}
      else
        echo "Warning: dropping ${f} without a nacl replacement."
        LogExecute rm -f ${f}
      fi
    elif [ "$(head -n 1 ${f} | grep /bin/sh)" != "" ]; then
      # TODO(bradnelson): Drop this once shell script fix is done.
      LogExecute cp -f ${BUILD_DIR}/driver/redirect.sh ${f}
      LogExecute chmod a+x ${f}
    fi
  done
}

PostInstallTestStep() {
  # Verify that binaries at least load under sel_ldr
  LogExecute ./le32-nacl-strings.sh --version
  LogExecute ./arm-nacl-readelf.sh --version
  # TODO(sbc): Currently this fails because the wrong main symbol is found
  # by the linker (the libppapi one rather than the libppapi_simple one).
  #LogExecute ./clang.sh --version
}
