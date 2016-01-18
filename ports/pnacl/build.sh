# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXECUTABLES="bin/arm-nacl-readelf bin/le32-nacl-strings bin/clang bin/clang++"
EnableGlibcCompat
EnableCliMain

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

OUT_DIR=${BUILD_DIR}/out
OUT_BIN=${BUILD_DIR}/bin

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

  EXTRA_CONFIGURE="--extra-configure-arg=--disable-compiler-version-checks"
  EXTRA_CONFIGURE+=" --extra-configure-arg=--enable-libcpp"

  # Some code in llvm uses intrisics not supported in the pnacl stable abi.
  if [[ ${TOOLCHAIN} == pnacl ]]; then
    EXTRA_CC_ARGS="-fgnu-inline-asm"
    EXTRA_CC_ARGS+=" --pnacl-disable-abi-check"
  fi
  if [[ ${TOOLCHAIN} != glibc ]]; then
    EXTRA_CC_ARGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  fi

  LINUX_PNACL=${NACL_SDK_ROOT}/toolchain/linux_pnacl
  EXTRA_CC_ARGS+=" -include spawn.h"
  EXTRA_CC_ARGS+=" -I${NACL_SDK_ROOT}/include"
  EXTRA_CC_ARGS+=" -I${NACLPORTS_INCLUDE}"

  # export EXTRA_LIBS so that compiler_wapper.py can access it
  export EXTRA_LIBS="${NACLPORTS_LDFLAGS} ${NACLPORTS_LIBS}"
  echo "EXTRA_LIBS=${EXTRA_LIBS}"

  # Without this configure will detect vfork as missing and define
  # vfork to fork which clobbers that define in "spawn.h".
  export ac_cv_func_vfork_works=yes

  # Inject a shim that speed up pnacl invocations for configure.
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    local PNACL_CONF_SHIM="${TOOLS_DIR}/pnacl-configure-shim.py"
    NACLCC="${PNACL_CONF_SHIM} ${NACLCC}"
    NACLCXX="${PNACL_CONF_SHIM} ${NACLCXX}"
  fi

  NACLCC="${START_DIR}/compiler_wrapper.py ${NACLCC}"
  NACLCXX="${START_DIR}/compiler_wrapper.py ${NACLCXX}"

  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  LogExecute ${SRC_DIR}/toolchain_build/toolchain_build_pnacl.py -v \
    --no-use-cached-results \
    --no-use-remote-cache \
    --no-annotator \
    --pnacl-in-pnacl \
    --output=${OUT_DIR} \
    "--extra-cc-args=${EXTRA_CC_ARGS}" \
    ${EXTRA_CONFIGURE} \
    "--binutils-pnacl-extra-configure=${GOLD_LDADD}"

  Remove ${OUT_BIN}
  MakeDir ${OUT_BIN}
  LogExecute cp ${OUT_DIR}/llvm_le32_nacl_install/bin/* ${OUT_BIN}
  LogExecute cp ${OUT_DIR}/binutils_pnacl_le32_nacl_install/bin/* \
    ${OUT_BIN}
  # TODO(bradnelson): Drop this once shell script fix is done.
  MakeDir ${OUT_BIN}/driver
  LogExecute cp ${SRC_DIR}/pnacl/driver/redirect.sh ${OUT_BIN}/driver/
  LogExecute cp ${SRC_DIR}/pnacl/driver/*.py ${OUT_BIN}/driver/
}

InstallStep() {
  local INSTALL_DIR=${DESTDIR}/${PREFIX}/pnacl
  Remove ${INSTALL_DIR}/
  MakeDir ${INSTALL_DIR}/

  LogExecute cp -r ${NACL_SDK_ROOT}/toolchain/linux_pnacl/* ${INSTALL_DIR}

  # Drop pyc files.
  LogExecute find ${INSTALL_DIR} -name "*.pyc" -exec rm {} \;

  LogExecute rm -rf ${INSTALL_DIR}/mipsel-nacl
  LogExecute rm -rf ${INSTALL_DIR}/translator
  LogExecute rm -rf ${INSTALL_DIR}/*-nacl/usr

  # TODO(bradnelson): Drop this once shell script fix is done.
  LogExecute cp ${OUT_BIN}/driver/*.py ${INSTALL_DIR}/bin/pydir/

  # Swap in nacl executables.
  Remove ${INSTALL_DIR}/lib/*.so
  for f in $(find ${INSTALL_DIR} -executable -type f); do
    if [ "$(file ${f} | grep ELF)" != "" ]; then
      local exe="${OUT_BIN}/$(basename ${f})"
      if [[ -f ${exe} ]]; then
        if [[ ${TOOLCHAIN} == pnacl ]]; then
          echo "Finalizing ${exe}"
          ${PNACLFINALIZE} ${exe} -o ${f}
        else
          echo "Copying ${exe}"
          cp ${exe} ${f}
        fi
      elif [[ $f == *-clang* ]]; then
        LogExecute ln -sf ${f} $(basename ${f})
      else
        echo "Warning: dropping ${f} without a nacl replacement."
        LogExecute rm -f ${f}
      fi
    elif [ "$(head -n 1 ${f} | grep /bin/sh)" != "" ]; then
      # TODO(bradnelson): Drop this once shell script fix is done.
      LogExecute cp -f ${OUT_BIN}/driver/redirect.sh ${f}
      LogExecute chmod a+x ${f}
    fi
  done
}

PostInstallTestStep() {
  # Verify that binaries at least load under sel_ldr
  LogExecute ./bin/le32-nacl-strings.sh --version
  LogExecute ./bin/arm-nacl-readelf.sh --version
  LogExecute ./bin/clang.sh --version
}
