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
  export NACL_ARCH=${NACL_ARCH:-"x86_64"}
fi

export NACL_GLIBC=${NACL_GLIBC:-0}

# Check NACL_ARCH
if [ ${NACL_ARCH} != "i686" -a ${NACL_ARCH} != "x86_64" -a \
     ${NACL_ARCH} != "arm" -a ${NACL_ARCH} != "pnacl" ]; then
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
elif [ ${NACL_ARCH} != "arm" ]; then
  # TODO(eugenis): Is this correct for PNACL?
  readonly NACL_SEL_LDR=${NACL_SDK_ROOT}/tools/sel_ldr_x86_64
  readonly NACL_IRT=${NACL_SDK_ROOT}/tools/irt_core_x86_64.nexe
fi

# NACL_CROSS_PREFIX is the prefix of the executables in the
# toolchain's "bin" directory. For example: i686-nacl-<toolname>.
if [ ${NACL_ARCH} = "pnacl" ]; then
  export NACL_CROSS_PREFIX=pnacl
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

  # NACL_SDK_GCC_SPECS_PATH is where nacl-gcc 'specs' file will be installed
  readonly NACL_SDK_GCC_SPECS_PATH=${NACL_TOOLCHAIN_ROOT}/lib/gcc/x86_64-nacl/4.4.3

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

  NACL_SDK_LIBDIR="${NACL_SDK_ROOT}/lib/${NACL_LIBC}_${NACL_ARCH_ALT}/Release"
}


InitializePNaClToolchain() {
  local TC_ROOT=${NACL_SDK_ROOT}/toolchain/${OS_SUBDIR}_x86_pnacl/${NACL_LIBC}
  readonly NACL_TOOLCHAIN_ROOT=${NACL_TOOLCHAIN_ROOT:-${TC_ROOT}}
  readonly NACL_BIN_PATH=${NACL_TOOLCHAIN_ROOT}/bin

  # export nacl tools for direct use in patches.
  export NACLCC=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-clang
  export NACLCXX=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-clang++
  export NACLAR=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ar
  export NACLRANLIB=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ranlib
  export NACLLD=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ld
  export NACLSTRINGS=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-strings
  export NACLSTRIP=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-strip
  # pnacl's translator
  export TRANSLATOR=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-translate
  # pnacl's pexe optimizer
  export PNACL_OPT=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-opt
  # TODO(robertm): figure our why we do not have a pnacl-string
  #export NACLSTRINGS=${NACL_BIN_PATH}/pnacl-strings
  # until then use the host's strings tool
  # (used only by the cairo package)
  export NACLSTRINGS="$(which strings)"

  NACL_SDK_LIBDIR="${NACL_SDK_ROOT}/lib/${NACL_ARCH_ALT}/Release"
}

if [ ${NACL_ARCH} = "pnacl" ]; then
  InitializePNaClToolchain
else
  InitializeNaClGccToolchain
fi

NACL_LDFLAGS="-L${NACL_SDK_LIBDIR}"
NACL_CFLAGS="-I${NACL_SDK_ROOT}/include"
NACL_CXXFLAGS="-I${NACL_SDK_ROOT}/include"

if [ $# -gt 0 ]; then
  if [ "$1" == '--print' ]; then
    echo "export CC=${NACLCC}"
    echo "export CXX=${NACLCXX}"
    echo "export AR=${NACLAR}"
    echo "export RANLIB=${NACLRANLIB}"
    echo "export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig"
    echo "export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}"
    echo "export PATH=\${PATH}:${NACL_BIN_PATH}"
    echo "export CFLAGS=\"${NACL_CFLAGS}\""
    echo "export LDFLAGS=\"${NACL_LDFLAGS}\""
  else
    export CC=${NACLCC}
    export CXX=${NACLCXX}
    export AR=${NACLAR}
    export RANLIB=${NACLRANLIB}
    export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
    export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
    export PATH=${PATH}:${NACL_BIN_PATH}
    export CFLAGS=${NACL_CFLAGS}
    exec $@
  fi
fi
