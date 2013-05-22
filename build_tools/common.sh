# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Environment variable NACL_ARCH should be unset or set to "i686"
# for a 32-bit build.  It should be set to "x86_64", "pnacl", or "arm"
# for a 64-bit, pnacl, or arm builds.


# NAMING CONVENTION
# =================
#
# This file is source'd by other scripts especially those inside libraries/
# and makes functions env variables available to those scripts.
# Only variables beginging with "NACL_" are intended to be used by those
# scripts!

set -o nounset
set -o errexit

# Scripts that source this file must be run from within the naclports src tree.
# Note that default build steps reference the packages directory.
readonly SAVE_PWD=$(pwd)

readonly SCRIPT_DIR=$(cd "$(dirname "$BASH_SOURCE")" ; pwd)
readonly START_DIR=$(cd "$(dirname "$0")" ; pwd)
readonly NACL_SRC=$(dirname ${SCRIPT_DIR})
readonly NACL_PACKAGES=${NACL_SRC}
readonly NACL_NATIVE_CLIENT_SDK=$(cd ${NACL_SRC} ; pwd)

# Pick platform directory for compiler.
readonly OS_NAME=$(uname -s)
if [ $OS_NAME = "Darwin" ]; then
  readonly OS_SUBDIR="mac"
  readonly OS_JOBS=4
elif [ $OS_NAME = "Linux" ]; then
  readonly OS_SUBDIR="linux"
  readonly OS_JOBS=$(cat /proc/cpuinfo | grep processor | wc -l)
else
  readonly OS_SUBDIR="win"
  readonly OS_JOBS=1
fi

# Set default NACL_ARCH based on legacy NACL_PACKAGES_BITSIZE
if [ "${NACL_PACKAGES_BITSIZE:-}" = "32" ]; then
  export NACL_ARCH=${NACL_ARCH:-"i686"}
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
    echo "NACL_GLIBC is does not work with pnacl" 1>&2
    exit -1
  fi
  if [ ${NACL_ARCH} = "arm" ]; then
    echo "NACL_GLIBC is does not work with arm" 1>&2
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

# configure spec for if MMX/SSE/SSE2/Assembly should be enabled/disabled
# TODO: Currently only x86-32 will encourage MMX, SSE & SSE2 intrinsics
#       and handcoded assembly.
if [ $NACL_ARCH = "i686" ]; then
  readonly NACL_OPTION="enable"
else
  readonly NACL_OPTION="disable"
fi

NACL_DEBUG=${NACL_DEBUG:-0}

# PACKAGE_DIR (the folder contained within that archive) defaults to
# the PACKAGE_NAME.  Packages with non-standard contents can override
# this before including common.sh
PACKAGE_DIR=${PACKAGE_DIR:-${PACKAGE_NAME:-}}

if [ -z "${NACL_SDK_ROOT:-}" ]; then
  echo "-------------------------------------------------------------------"
  echo "NACL_SDK_ROOT is unset."
  echo "This environment variable needs to be pointed at some version of"
  echo "the Native Client SDK (the directory containing toolchain/)."
  echo "NOTE: set this to an absolute path."
  echo "-------------------------------------------------------------------"
  exit -1
fi

# When run by a buildbot force all archives to come from the NaCl mirror
# rather than using upstream URL.
if [ -n ${BUILDBOT_BUILDERNAME:-""} ]; then
   FORCE_MIRROR=${FORCE_MIRROR:-"yes"}
fi

# sha1check python script
readonly SHA1CHECK=${SCRIPT_DIR}/sha1check.py

# packages subdirectories
readonly NACL_PACKAGES_LIBRARIES=${NACL_PACKAGES}/libraries
readonly NACL_PACKAGES_OUT=${NACL_SRC}/out
REPOSITORY=${NACL_PACKAGES_OUT}/repository-${NACL_ARCH}
if [ ${NACL_DEBUG} = "1" ]; then
  REPOSITORY=${REPOSITORY}-debug
fi
readonly NACL_PACKAGES_REPOSITORY=${REPOSITORY}
readonly NACL_PACKAGES_PUBLISH=${NACL_PACKAGES_OUT}/publish
readonly NACL_PACKAGES_TARBALLS=${NACL_PACKAGES_OUT}/tarballs


InitializeNaClGccToolchain() {
  # locate default nacl_sdk toolchain
  # TODO: x86 only at the moment
  if [ $NACL_ARCH = "arm" ]; then
    local TOOLCHAIN_ARCH="arm"
  else
    local TOOLCHAIN_ARCH="x86"
  fi

  local TOOLCHAIN_DIR=${OS_SUBDIR}_${TOOLCHAIN_ARCH}_${NACL_LIBC}

  readonly NACL_TOOLCHAIN_ROOT=${NACL_TOOLCHAIN_ROOT:-${NACL_SDK_ROOT}/toolchain/${TOOLCHAIN_DIR}}
  # TODO(robertm): can we get rid of NACL_SDK_BASE?
  readonly NACL_SDK_BASE=${NACL_SDK_BASE:-${NACL_TOOLCHAIN_ROOT}}

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

  # NACLPORTS_PREFIX is where the headers, libraries, etc. will be installed
  # Default to the usr folder within the SDK.
  readonly NACLPORTS_PREFIX=${NACLPORTS_PREFIX:-${NACL_TOOLCHAIN_ROOT}/${NACL_CROSS_PREFIX}/usr}
  readonly NACL_SDK_LIB=${NACL_TOOLCHAIN_ROOT}/${NACL_LIBDIR}

  # There are a few .la files that ship with the SDK that
  # contain hardcoded paths that point to the build location
  # on the machine where the SDK itself was built.
  # TODO(sbc): remove this hack once these files are removed from the
  # SDK or fixed.
  LA_FILES=$(echo ${NACL_SDK_LIB}/*.la)
  echo ${LA_FILES}
  if [ "${LA_FILES}" != "${NACL_SDK_LIB}/*.la" ]; then
    for LA_FILE in ${LA_FILES}; do
      mv ${LA_FILE} ${LA_FILE}.old
    done
  fi

  # NACL_SDK_MULITARCH_USR is a version of NACLPORTS_PREFIX that gets passed into
  # the gcc specs file.  It has a gcc spec-file conditional for ${NACL_ARCH}
  readonly NACL_SDK_MULTIARCH_USR=${NACL_TOOLCHAIN_ROOT}/\%\(nacl_arch\)/usr
  readonly NACL_SDK_MULTIARCH_USR_INCLUDE=${NACL_SDK_MULTIARCH_USR}/include
  readonly NACL_SDK_MULTIARCH_USR_LIB=${NACL_SDK_MULTIARCH_USR}/lib
  NACL_SDK_LIBDIR="${NACL_SDK_ROOT}/lib/${NACL_LIBC}_${NACL_ARCH_ALT}/Release"
}


InitializePNaClToolchain() {
  local TC_ROOT=${NACL_SDK_ROOT}/toolchain/${OS_SUBDIR}_x86_pnacl/${NACL_LIBC}
  readonly NACL_TOOLCHAIN_ROOT=${NACL_TOOLCHAIN_ROOT:-${TC_ROOT}}
  readonly NACL_SDK_BASE=${NACL_SDK_BASE:-${NACL_TOOLCHAIN_ROOT}}
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
  export OPT=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-opt
  # TODO(robertm): figure our why we do not have a pnacl-string
  #export NACLSTRINGS=${NACL_BIN_PATH}/pnacl-strings
  # until then use the host's strings tool
  # (used only by the cairo package)
  export NACLSTRINGS="$(which strings)"

  # NACLPORTS_PREFIX is where the headers, libraries, etc. will be installed
  # Default to the usr folder within the SDK.
  readonly NACLPORTS_PREFIX=${NACLPORTS_PREFIX:-${NACL_SDK_BASE}/usr}
  NACL_SDK_LIBDIR="${NACL_SDK_ROOT}/lib/${NACL_ARCH_ALT}/Release"
}

if [ ${NACL_ARCH} = "pnacl" ]; then
  InitializePNaClToolchain
else
  InitializeNaClGccToolchain
fi

readonly NACLPORTS_INCLUDE=${NACLPORTS_PREFIX}/include
readonly NACLPORTS_LIBDIR=${NACLPORTS_PREFIX}/lib
readonly NACLPORTS_PREFIX_BIN=${NACLPORTS_PREFIX}/bin
NACLPORTS_CFLAGS="-I${NACLPORTS_INCLUDE} -I${NACL_SDK_ROOT}/include"
NACLPORTS_LDFLAGS=" -L${NACLPORTS_LIBDIR} -L${NACL_SDK_LIBDIR}"

# The NaCl version of ARM gcc emits warnings about va_args that
# are not particularly useful
if [ $NACL_ARCH = "arm" ]; then
  NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS} -Wno-psabi"
fi

if [ ${NACL_DEBUG} = "1" ]; then
  NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS} -g -O0"
fi

export CFLAGS=${NACLPORTS_CFLAGS}
export CXXFLAGS=${NACLPORTS_CFLAGS}
export LDFLAGS=${NACLPORTS_LDFLAGS}

######################################################################
# Always run
######################################################################

CheckPatchVersion() {
  # refuse patch 2.6
  if ! which patch > /dev/null; then
    echo 'patch command not found, please install and try again.'
    exit 1
  fi
  if [ "`patch --version 2> /dev/null | sed q`" = "patch 2.6" ]; then
    echo "patch 2.6 is incompatible with these scripts."
    echo "Please install either version 2.5.9 (or earlier)"
    echo "or version 2.6.1 (or later.)"
    exit -1
  fi
}

CheckPatchVersion

CheckSDKVersion() {
  if [ -z "${MIN_SDK_VERSION:-}" ]; then
    return
  fi
  local GETOS=${NACL_SDK_ROOT}/tools/getos.py
  local RESULT=$(${GETOS} --check-version=${MIN_SDK_VERSION} 2>&1)
  if [ -n "${RESULT:-}" ]; then
    echo "The SDK in \$NACL_SDK_ROOT is too old to build ${PACKAGE_NAME}."
    echo ${RESULT}
    exit -1
  fi
}

CheckSDKVersion

######################################################################
# Helper functions
######################################################################

Banner() {
  echo "######################################################################"
  echo $*
  echo "######################################################################"
}


Usage() {
  egrep "^#@" $0 | cut --bytes=3-
}


ReadKey() {
  read
}


ArchiveName() {
  if [ -z "${ARCHIVE_NAME:-}" ]; then
    ARCHIVE_NAME=${URL_FILENAME:-$(basename ${URL})}
  fi
}

TryFetch() {
  Banner "Fetching ${PACKAGE_NAME} ($2)"
  if which wget > /dev/null ; then
    wget $1 -O $2
  elif which curl > /dev/null ; then
    curl --location --url $1 -o $2
  else
     Banner "Problem encountered"
     echo "Please install curl or wget and rerun this script"
     echo "or manually download $1 to $2"
     echo
     echo "press any key when done"
     ReadKey
  fi
}


Fetch() {
  local MIRROR_URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl
  if echo $1 | grep -qv ${MIRROR_URL} &> /dev/null; then
    set +o errexit
    # Try mirrored version first
    local BASENAME=${URL_FILENAME:-$(basename $1)}
    TryFetch ${MIRROR_URL}/${BASENAME} $2
    if [ $? != 0 -a ${FORCE_MIRROR:-no} = "no" ]; then
      # Fall back to original URL
      TryFetch $1 $2
    fi
    set -o errexit
  else
    # The URL is already on commondatastorage do just download it
    TryFetch $1 $2
  fi

  if [ ! -s $2 ]; then
    echo "ERROR: could not find $2"
    exit -1
  fi
}


Check() {
  # verify sha1 checksum for tarball
  local IN_FILE=${START_DIR}/${PACKAGE_NAME}.sha1

  if ${SHA1CHECK} <${IN_FILE} ; then
    return 0
  else
    return 1
  fi
}


DefaultDownloadStep() {
  ArchiveName
  cd ${NACL_PACKAGES_TARBALLS}
  # if matching tarball already exists, don't download again
  if ! Check ; then
    Fetch ${URL} ${ARCHIVE_NAME}
    if ! Check ; then
       Banner "${PACKAGE_NAME} failed checksum!"
       exit -1
    fi
  fi
}


Patch() {
  local LOCAL_PATCH_FILE=$1
  if [ ${#LOCAL_PATCH_FILE} -ne 0 ]; then
    Banner "Patching $(basename ${PWD})"
    #git apply ${START_DIR}/${LOCAL_PATCH_FILE}
    patch -p1 -g0 --no-backup-if-mismatch < ${START_DIR}/${LOCAL_PATCH_FILE}
    git add .
    git commit -m "Apply naclports patch"
  fi
}


VerifyPath() {
  # make sure path isn't all slashes (possibly from an unset variable)
  local PATH=$1
  local TRIM=${PATH##/}
  if [ ${#TRIM} -ne 0 ]; then
    return 0
  else
    return 1
  fi
}


ChangeDir() {
  local NAME=$1
  if VerifyPath ${NAME}; then
    cd ${NAME}
  else
    echo "ChangeDir called with bad path."
    exit -1
  fi
}


Remove() {
  local NAME=$1
  if VerifyPath ${NAME}; then
    rm -rf ${NAME}
  else
    echo "Remove called with bad path."
    exit -1
  fi
}


MakeDir() {
  local NAME=$1
  if VerifyPath ${NAME}; then
    mkdir -p ${NAME}
  else
    echo "MakeDir called with bad path."
    exit -1
  fi
}


PatchSpecFile() {
  # fix up spaces so gcc sees entire path
  local SED_SAFE_SPACES_USR_INCLUDE=${NACL_SDK_MULTIARCH_USR_INCLUDE/ /\ /}
  local SED_SAFE_SPACES_USR_LIB=${NACL_SDK_MULTIARCH_USR_LIB/ /\ /}
  # have nacl-gcc dump specs file & add include & lib search paths
  ${NACLCC} -dumpspecs |\
    awk '/\*cpp:/ {\
      printf("*nacl_arch:\n%%{m64:x86_64-nacl; m32:i686-nacl; :x86_64-nacl}\n\n", $1); } \
      { print $0; }' |\
    sed "/*cpp:/{
      N
      s|$| -isystem ${SED_SAFE_SPACES_USR_INCLUDE}|
    }" |\
    sed "/*link_libgcc:/{
      N
      s|$| -L${SED_SAFE_SPACES_USR_LIB}|
    }" >${NACL_SDK_GCC_SPECS_PATH}/specs
}


DefaultPreInstallStep() {
  cd ${NACL_NATIVE_CLIENT_SDK}/..
  MakeDir ${NACLPORTS_PREFIX}
  MakeDir ${NACLPORTS_INCLUDE}
  MakeDir ${NACLPORTS_LIBDIR}
  MakeDir ${NACL_PACKAGES_REPOSITORY}
  MakeDir ${NACL_PACKAGES_TARBALLS}
  MakeDir ${NACL_PACKAGES_PUBLISH}
  Remove ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
}


InitGitRepo() {
  if [ -d .git ]; then
    # Strangely one of the upstream archives (x264) actually contains a full
    # .git repo already. In this case we can just skip the initial commit.
    # TODO(sbc): remove this once x264 is updated.
    return
  fi
  git init
  if [ -n ${BUILDBOT_BUILDERNAME:-""} ]; then
    if [ -z "$(git config user.email)" ]; then
      git config user.email "naclports_buildbot"
    fi
    if [ -z "$(git config user.name)" ]; then
      git config user.name "naclports buildbot"
    fi
  fi
  git checkout -b "upstream"
  git add .
  git commit -m "Upstream version"
  git checkout -b "master"
}


DefaultExtractStep() {
  ArchiveName
  Banner "Extracting ${ARCHIVE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  Remove ${PACKAGE_DIR}

  local EXTENSION="${ARCHIVE_NAME##*.}"
  if [ ${EXTENSION} = "zip" ]; then
    unzip ${NACL_PACKAGES_TARBALLS}/${ARCHIVE_NAME}
  else
    if [ $OS_SUBDIR = "win" ]; then
      tar --no-same-owner -xf ${NACL_PACKAGES_TARBALLS}/${ARCHIVE_NAME}
    else
      tar xf ${NACL_PACKAGES_TARBALLS}/${ARCHIVE_NAME}
    fi
  fi

}


PatchConfigSub() {
  # Replace the package's config.sub one with an up-do-date copy
  # that includes nacl support.  We only do this if the string
  # 'nacl' is not already contained in the file.
  local CONFIG_SUB=${CONFIG_SUB:-config.sub}
  if [ -f $CONFIG_SUB ]; then
    if grep -q nacl $CONFIG_SUB /dev/null; then
      echo "$CONFIG_SUB supports NaCl"
    else
      echo "Patching config.sub"
      /bin/cp -f ${SCRIPT_DIR}/config.sub $CONFIG_SUB
    fi
  fi
}


PatchConfigure() {
  if [ -f configure ]; then
    Banner "Patching configure"
    ${SCRIPT_DIR}/patch_configure.py configure
  fi
}


DefaultPatchStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  InitGitRepo
  if [ -n "${PATCH_FILE:-}" ]; then
    Patch ${PATCH_FILE}
  fi
  PatchConfigure
  PatchConfigSub
  if [ -n "$(git diff)" ]; then
    git add -u
    git commit -m "Automatic patch generated by naclports"
  fi
}


DefaultConfigureStep() {
  local EXTRA_CONFIGURE_OPTS=("${@:-}")
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export FREETYPE_CONFIG=${NACLPORTS_PREFIX_BIN}/freetype-config
  export PATH=${NACL_BIN_PATH}:${PATH};
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
  Remove build-nacl
  MakeDir build-nacl
  cd build-nacl
  echo "Directory: $(pwd)"

  local conf_host=${NACL_CROSS_PREFIX}
  if [ ${NACL_ARCH} = "pnacl" ]; then
    # The PNaCl tools use "pnacl-" as the prefix, but config.sub
    # does not know about "pnacl".  It only knows about "le32-nacl".
    # Unfortunately, most of the config.subs here are so old that
    # it doesn't know about that "le32" either.  So we just say "nacl".
    conf_host="nacl"
  fi
  LogExecute ../configure \
    --host=${conf_host} \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    --oldincludedir=${NACLPORTS_INCLUDE} \
    --with-http=no \
    --with-html=no \
    --with-ftp=no \
    --${NACL_OPTION}-mmx \
    --${NACL_OPTION}-sse \
    --${NACL_OPTION}-sse2 \
    --${NACL_OPTION}-asm \
    --with-x=no  \
    "${EXTRA_CONFIGURE_OPTS[@]}" ${EXTRA_CONFIGURE_ARGS:-}
}


# echo a command to stdout and then execute it.
LogExecute() {
  echo $*
  $*
}


DefaultBuildStep() {
  Banner "Build ${PACKAGE_NAME}"
  echo "Directory: $(pwd)"
  # assumes pwd has makefile
  LogExecute make clean
  # Build ${MAKE_TARGETS} or default target if it is not defined
  LogExecute make -j${OS_JOBS} ${MAKE_TARGETS:-}
}


DefaultTouchStep() {
  FULL_PACKAGE="${START_DIR/#${NACL_PACKAGES}\//}"
  SENTFILE="${NACL_PACKAGES_OUT}/sentinels/${NACL_ARCH}/${FULL_PACKAGE}"
  SENTDIR=$(dirname "${SENTFILE}")
  mkdir -p "${SENTDIR}" && touch "${SENTFILE}"
}


DefaultInstallStep() {
  # assumes pwd has makefile
  LogExecute make ${INSTALL_TARGETS:-install}
  DefaultTouchStep
}


DefaultCleanUpStep() {
  if [ ${NACL_ARCH} != "pnacl" -a ${NACL_ARCH} != "arm" ]; then
    PatchSpecFile
  fi
  ChangeDir ${SAVE_PWD}
}


# echo a command before exexuting it under 'time'
TimeCommand() {
  echo "$@"
  time "$@"
}

Validate() {
  if [ ${NACL_ARCH} = "pnacl" ]; then
      return
  elif [ ${NACL_ARCH} = "arm" ]; then
      NACL_VALIDATE=${NACL_SDK_ROOT}/tools/ncval_arm
  elif [ ${NACL_ARCH} = "x86_64" ]; then
      NACL_VALIDATE="${NACL_SDK_ROOT}/tools/ncval_x86_64 --errors"
  else
      NACL_VALIDATE=${NACL_SDK_ROOT}/tools/ncval_x86_32
  fi
  LogExecute ${NACL_VALIDATE} $@
  if [ $? != 0 ]; then
      exit 1
  fi
}


DefaultValidateStep() {
  if [ ${NACL_ARCH} != "pnacl" -a -n "${EXECUTABLES:-}" ]; then
    for nexe in $EXECUTABLES ; do
      Validate $nexe
    done
  fi
}


RunSelLdrCommand() {
  if [ $NACL_ARCH = "arm" ]; then
    # no sel_ldr for arm
    return
  fi
  echo "[sel_ldr] $@"
  if [ $NACL_GLIBC = "1" ]; then
    time "${NACL_SEL_LDR}" -a -B "${NACL_IRT}" -- \
        "${NACL_SDK_LIB}/runnable-ld.so" \
        --library-path "${NACL_SDK_LIBDIR}:${NACL_SDK_LIB}" "$@"
  else
    time "${NACL_SEL_LDR}" -a -B "${NACL_IRT}" -- "$@"
  fi
}


WriteSelLdrScript() {
  if [ $NACL_ARCH = "arm" ]; then
    # no sel_ldr for arm
    return
  fi
  if [ $NACL_GLIBC = "1" ]; then
    cat > $1 <<HERE
#!/bin/bash
export NACLLOG=/dev/null

SCRIPT_DIR=\$(dirname "\${BASH_SOURCE[0]}")
SEL_LDR=${NACL_SEL_LDR}
IRT=${NACL_IRT}
SDK_LIB_DIR=${NACL_SDK_LIB}
LIB_PATH=${NACL_SDK_LIBDIR}:\${SDK_LIB_DIR}:\${SCRIPT_DIR}

"\${SEL_LDR}" -a -B "\${IRT}" -- \\
    "\${SDK_LIB_DIR}/runnable-ld.so" --library-path "\${LIB_PATH}" \\
    "\${SCRIPT_DIR}/$2" "\$@"
HERE
  else
    cat > $1 <<HERE
#!/bin/bash
export NACLLOG=/dev/null

SCRIPT_DIR=\$(dirname "\${BASH_SOURCE[0]}")
SEL_LDR=${NACL_SEL_LDR}
IRT=${NACL_IRT}

"\${SEL_LDR}" -B "\${IRT}" -- "\${SCRIPT_DIR}/$2" "\$@"
HERE
  fi
  chmod 750 $1
  echo "Wrote script pwd:$PWD $1"
}


TranslatePexe() {
  local pexe=$1
  local arches="arm x86-32 x86-64"
  Banner "Translating ${pexe}"

  echo "stripping pexe"
  TimeCommand ${NACLSTRIP} ${pexe} -o ${pexe}.stripped

  for a in ${arches} ; do
    echo "translating pexe [$a]"
    nexe=${pexe}.$a.nexe
    TimeCommand ${TRANSLATOR} -arch $a ${pexe}.stripped -o ${nexe}
  done

  # PIC branch
  for a in ${arches} ; do
    echo "translating pexe [$a,pic]"
    nexe=${pexe}.$a.pic.nexe
    TimeCommand ${TRANSLATOR} -arch $a -fPIC ${pexe}.stripped -o ${nexe}
  done

  # Now the same spiel with an optimized pexe
  opt_args="-O3 -inline-threshold=100"
  echo "optimizing pexe [${opt_args}]"
  TimeCommand ${OPT} ${opt_args} ${pexe}.stripped -o ${pexe}.stripped.opt

  for a in ${arches} ; do
    echo "translating pexe [$a]"
    nexe=${pexe}.opt.$a.nexe
    TimeCommand ${TRANSLATOR} -arch $a ${pexe}.stripped.opt -o ${nexe}
  done

  # PIC branch
  for a in ${arches}; do
    echo "translating pexe [$a,pic]"
    nexe=${pexe}.$a.pic.opt.nexe
    TimeCommand ${TRANSLATOR} -arch $a -fPIC ${pexe}.stripped.opt -o ${nexe}
  done

  ls -l $(dirname ${pexe})/*.nexe ${pexe}
}


DefaultTranslateStep() {
  if [ ${NACL_ARCH} = "pnacl" -a -n "${EXECUTABLES:-}" ]; then
    for pexe in ${EXECUTABLES} ; do
      TranslatePexe ${pexe}
    done
  fi
}


DefaultPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  DefaultConfigureStep
  DefaultBuildStep
  DefaultTranslateStep
  DefaultValidateStep
  DefaultInstallStep
  DefaultCleanUpStep
}
