#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Echo the environment variables need to to build/configure standard
# GNU make/automake/configure projects.
#
# To import these variables into your environment do:
# $ . nacl_env.sh
#
# Alternatively you can see just the essential environment
# variables by passing --print.  This can by used within
# a script using:
# eval `./nacl_env.sh --print`
#
# Finally you can run a command within the NaCl environment
# by passing the command line. e.g:
# ./nacl_env.sh make

if [ -z "${NACL_SDK_ROOT:-}" ]; then
  echo "-------------------------------------------------------------------"
  echo "NACL_SDK_ROOT is unset."
  echo "This environment variable needs to be pointed at some version of"
  echo "the Native Client SDK (the directory containing toolchain/)."
  echo "NOTE: set this to an absolute path."
  echo "-------------------------------------------------------------------"
  exit -1
fi

# Pick platform directory for compiler.
readonly OS_NAME=$(uname -s)
if [ $OS_NAME = "Darwin" ]; then
  readonly OS_SUBDIR="mac"
elif [ $OS_NAME = "Linux" ]; then
  readonly OS_SUBDIR="linux"
else
  readonly OS_SUBDIR="win"
fi

# Set default NACL_ARCH based on legacy NACL_PACKAGES_BITSIZE
if [ "${NACL_PACKAGES_BITSIZE:-}" = "64" ]; then
  export NACL_ARCH=${NACL_ARCH:-"x86_64"}
elif [ "${NACL_PACKAGES_BITSIZE:-}" = "pnacl" ]; then
  export NACL_ARCH=${NACL_ARCH:-"pnacl"}
else
  # On mac we default ot i686 rather than x86_64 since
  # since there is no x86_64 chrome yet and its nice for
  # the default binaries to run on the host machine.
  if [ "${OS_NAME}" = "Darwin" ]; then
    export NACL_ARCH=${NACL_ARCH:-"i686"}
  else
    export NACL_ARCH=${NACL_ARCH:-"x86_64"}
  fi
fi

if [ "${NACL_ARCH}" = "emscripten" -a -z "${PEPPERJS_SRC_ROOT:-}" ]; then
  echo "-------------------------------------------------------------------"
  echo "PEPPERJS_SRC_ROOT is unset."
  echo "This environment variable needs to be pointed at some version of"
  echo "the pepper.js repository."
  echo "NOTE: set this to an absolute path."
  echo "-------------------------------------------------------------------"
  exit -1
fi

export NACL_GLIBC=${NACL_GLIBC:-0}

# Check NACL_ARCH
if [ ${NACL_ARCH} != "i686" -a ${NACL_ARCH} != "x86_64" -a \
     ${NACL_ARCH} != "arm" -a ${NACL_ARCH} != "pnacl" -a \
     ${NACL_ARCH} != "emscripten" ]; then
  echo "Unknown value for NACL_ARCH: '${NACL_ARCH}'" 1>&2
  exit -1
fi

# In some places i686 is also known as x86_32 so we use
# second variable to store this alternate architecture
# name
if [ ${NACL_ARCH} = "i686" ]; then
  export NACL_ARCH_ALT="x86_32"
else
  export NACL_ARCH_ALT=${NACL_ARCH}
fi

if [ ${NACL_GLIBC} = "1" ]; then
  if [ ${NACL_ARCH} = "pnacl" ]; then
    echo "NACL_GLIBC does not work with pnacl" 1>&2
    exit -1
  fi
  if [ ${NACL_ARCH} = "arm" ]; then
    echo "NACL_GLIBC does not work with arm" 1>&2
    exit -1
  fi
  export NACL_LIBC="glibc"
else
  export NACL_LIBC="newlib"
fi

if [ ${NACL_ARCH} = "i686" ]; then
  readonly NACL_SEL_LDR=${NACL_SDK_ROOT}/tools/sel_ldr_x86_32
  readonly NACL_IRT=${NACL_SDK_ROOT}/tools/irt_core_x86_32.nexe
elif [ ${NACL_ARCH} = "pnacl" ]; then
  readonly NACL_SEL_LDR_X8632=${NACL_SDK_ROOT}/tools/sel_ldr_x86_32
  readonly NACL_IRT_X8632=${NACL_SDK_ROOT}/tools/irt_core_x86_32.nexe
  readonly NACL_SEL_LDR_X8664=${NACL_SDK_ROOT}/tools/sel_ldr_x86_64
  readonly NACL_IRT_X8664=${NACL_SDK_ROOT}/tools/irt_core_x86_64.nexe
elif [ ${NACL_ARCH} = "x86_64" -a ${OS_NAME} != "Darwin" ]; then
  # No 64-bit sel_ldr on darwin today.
  readonly NACL_SEL_LDR=${NACL_SDK_ROOT}/tools/sel_ldr_x86_64
  readonly NACL_IRT=${NACL_SDK_ROOT}/tools/irt_core_x86_64.nexe
fi

# NACL_CROSS_PREFIX is the prefix of the executables in the
# toolchain's "bin" directory. For example: i686-nacl-<toolname>.
if [ ${NACL_ARCH} = "pnacl" ]; then
  export NACL_CROSS_PREFIX=pnacl
elif [ ${NACL_ARCH} = "emscripten" ]; then
  export NACL_CROSS_PREFIX=em
else
  export NACL_CROSS_PREFIX=${NACL_ARCH}-nacl
fi

InitializeNaClGccToolchain() {
  if [ $NACL_ARCH = "arm" ]; then
    local TOOLCHAIN_ARCH="arm"
  else
    local TOOLCHAIN_ARCH="x86"
  fi

  local TOOLCHAIN_DIR=${OS_SUBDIR}_${TOOLCHAIN_ARCH}_${NACL_LIBC}

  readonly NACL_TOOLCHAIN_ROOT=${NACL_TOOLCHAIN_ROOT:-${NACL_SDK_ROOT}/toolchain/${TOOLCHAIN_DIR}}
  readonly NACL_BIN_PATH=${NACL_TOOLCHAIN_ROOT}/bin

  # export nacl tools for direct use in patches.
  export NACLCC=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-gcc
  export NACLCXX=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-g++
  export NACLAR=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ar
  export NACLRANLIB=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ranlib
  export NACLLD=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ld
  export NACLSTRINGS=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-strings
  export NACLSTRIP=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-strip
  export NACLREADELF=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-readelf
  export NACL_EXEEXT=".nexe"

  if [ ${NACL_ARCH} = "arm" ]; then
    local NACL_LIBDIR=arm-nacl/lib
  elif [ ${NACL_ARCH} = "x86_64" ]; then
    local NACL_LIBDIR=x86_64-nacl/lib64
  else
    local NACL_LIBDIR=x86_64-nacl/lib32
  fi

  readonly NACL_SDK_LIB=${NACL_TOOLCHAIN_ROOT}/${NACL_LIBDIR}

  # There are a few .la files that ship with the SDK that
  # contain hardcoded paths that point to the build location
  # on the machine where the SDK itself was built.
  # TODO(sbc): remove this hack once these files are removed from the
  # SDK or fixed.
  LA_FILES=$(echo ${NACL_SDK_LIB}/*.la)
  if [ "${LA_FILES}" != "${NACL_SDK_LIB}/*.la" ]; then
    for LA_FILE in ${LA_FILES}; do
      mv ${LA_FILE} ${LA_FILE}.old
    done
  fi

  if [ "${NACL_DEBUG:-}" = "1" ]; then
    NACL_SDK_LIBDIR="${NACL_SDK_ROOT}/lib/${NACL_LIBC}_${NACL_ARCH_ALT}/Debug"
  else
    NACL_SDK_LIBDIR="${NACL_SDK_ROOT}/lib/${NACL_LIBC}_${NACL_ARCH_ALT}/Release"
  fi
}

InitializeEmscriptenToolchain() {
  local TC_ROOT=${NACL_SDK_ROOT}/toolchain
  local EM_ROOT=${PEPPERJS_SRC_ROOT}/emscripten

  # The PNaCl toolchain moved in pepper_31.  Check for
  # the existence of the old folder first and use that
  # if found.
  if [ -d "${TC_ROOT}/${OS_SUBDIR}_x86_pnacl" ]; then
    TC_ROOT=${TC_ROOT}/${OS_SUBDIR}_x86_pnacl/newlib
  elif [ -d "${TC_ROOT}/${OS_SUBDIR}_pnacl/newlib" ]; then
    TC_ROOT=${TC_ROOT}/${OS_SUBDIR}_pnacl/newlib
  else
    TC_ROOT=${TC_ROOT}/${OS_SUBDIR}_pnacl
  fi

  readonly NACL_TOOLCHAIN_ROOT=${EM_ROOT}
  readonly NACL_BIN_PATH=${EM_ROOT}

  # export emscripten tools for direct use in patches.
  export NACLCC=${EM_ROOT}/emcc
  export NACLCXX=${EM_ROOT}/em++
  export NACLAR=${EM_ROOT}/emar
  export NACLRANLIB=${EM_ROOT}/emranlib
  export NACLLD=${EM_ROOT}/em++
  export NACLSTRINGS=/bin/true
  export NACLSTRIP=/bin/true
  export NACL_EXEEXT=".js"
  export LLVM=${TC_ROOT}/bin

  if [ "${NACL_DEBUG:-}" = "1" ]; then
    NACL_SDK_LIBDIR="${PEPPERJS_SRC_ROOT}/lib/emscripten/Debug"
  else
    NACL_SDK_LIBDIR="${PEPPERJS_SRC_ROOT}/lib/emscripten/Release"
  fi
}


InitializePNaClToolchain() {
  local TC_ROOT=${NACL_SDK_ROOT}/toolchain
  # The PNaCl toolchain moved in pepper_31.  Check for
  # the existence of the old folder first and use that
  # if found.
  if [ -d "${TC_ROOT}/${OS_SUBDIR}_x86_pnacl" ]; then
    TC_ROOT=${TC_ROOT}/${OS_SUBDIR}_x86_pnacl/newlib
  elif [ -d "${TC_ROOT}/${OS_SUBDIR}_pnacl/newlib" ]; then
    TC_ROOT=${TC_ROOT}/${OS_SUBDIR}_pnacl/newlib
  else
    TC_ROOT=${TC_ROOT}/${OS_SUBDIR}_pnacl
  fi

  readonly NACL_TOOLCHAIN_ROOT=${NACL_TOOLCHAIN_ROOT:-${TC_ROOT}}
  readonly NACL_BIN_PATH=${NACL_TOOLCHAIN_ROOT}/bin

  # export nacl tools for direct use in patches.
  export NACLCC=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-clang
  export NACLCXX=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-clang++
  export NACLAR=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ar
  export NACLRANLIB=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ranlib
  export NACLREADELF=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-readelf
  export NACLLD=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ld
  export NACLSTRINGS=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-strings
  export NACLSTRIP=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-strip
  # pnacl's translator
  export TRANSLATOR=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-translate
  export PNACLFINALIZE=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-finalize
  # pnacl's pexe optimizer
  export PNACL_OPT=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-opt
  # TODO(robertm): figure our why we do not have a pnacl-string
  #export NACLSTRINGS=${NACL_BIN_PATH}/pnacl-strings
  # until then use the host's strings tool
  # (used only by the cairo package)
  export NACLSTRINGS="$(which strings)"
  export NACL_EXEEXT=".pexe"

  if [ "${NACL_DEBUG:-}" = "1" ]; then
    NACL_SDK_LIBDIR="${NACL_SDK_ROOT}/lib/${NACL_ARCH_ALT}/Debug"
  else
    NACL_SDK_LIBDIR="${NACL_SDK_ROOT}/lib/${NACL_ARCH_ALT}/Release"
  fi
}

if [ ${NACL_ARCH} = "pnacl" ]; then
  InitializePNaClToolchain
elif [ ${NACL_ARCH} = "emscripten" ]; then
  InitializeEmscriptenToolchain
else
  InitializeNaClGccToolchain
fi

NACL_LDFLAGS="-L${NACL_SDK_LIBDIR}"
NACL_CPPFLAGS="-I${NACL_SDK_ROOT}/include"

if [ ${NACL_GLIBC} = "1" ]; then
  NACL_LDFLAGS+=" -Wl,-rpath-link=${NACL_SDK_LIBDIR}"
fi

if [ -z "${NACL_ENV_IMPORT:-}" ]; then
  if [ $# -gt 0 ]; then
    if [ "$1" = '--print' ]; then
      echo "export CC=${NACLCC}"
      echo "export CXX=${NACLCXX}"
      echo "export AR=${NACLAR}"
      echo "export RANLIB=${NACLRANLIB}"
      echo "export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig"
      echo "export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}"
      echo "export PATH=\${PATH}:${NACL_BIN_PATH}"
      echo "export CPPFLAGS=\"${NACL_CPPFLAGS}\""
      echo "export LDFLAGS=\"${NACL_LDFLAGS}\""
    else
      export CC=${NACLCC}
      export CXX=${NACLCXX}
      export AR=${NACLAR}
      export RANLIB=${NACLRANLIB}
      export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
      export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
      export PATH=${PATH}:${NACL_BIN_PATH}
      export CPPFLAGS=${NACL_CPPFLAGS}
      exec $@
    fi
  fi
fi
