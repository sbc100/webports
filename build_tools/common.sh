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
# This file is source'd by the main naclports build script.  Functions
# and variables defined here are available in the build script for
# individual ports.  Only variables beginging with "NACL_" are intended
# to be used by those scripts.

set -o nounset
set -o errexit

readonly TOOLS_DIR=$(cd "$(dirname "$BASH_SOURCE")" ; pwd)
readonly START_DIR=$PWD
readonly NACL_SRC=$(dirname ${TOOLS_DIR})
readonly NACL_PACKAGES=${NACL_SRC}
readonly NACL_NATIVE_CLIENT_SDK=$(cd ${NACL_SRC} ; pwd)
NACL_DEBUG=${NACL_DEBUG:-0}

NACL_ENV_IMPORT=1
. ${TOOLS_DIR}/nacl_env.sh

# When run by a buildbot force all archives to come from the NaCl mirror
# rather than using upstream URL.
if [ -n ${BUILDBOT_BUILDERNAME:-""} ]; then
  FORCE_MIRROR=${FORCE_MIRROR:-"yes"}
fi

# sha1check python script
readonly SHA1CHECK=${TOOLS_DIR}/sha1check.py

if [ "${NACL_ARCH}" = "pnacl" ]; then
  readonly NACL_TOOLCHAIN_INSTALL=${NACL_TOOLCHAIN_ROOT}
elif [ "${NACL_ARCH}" = "emscripten" ]; then
  readonly NACL_TOOLCHAIN_INSTALL=${NACL_TOOLCHAIN_ROOT}
else
  readonly NACL_TOOLCHAIN_INSTALL=${NACL_TOOLCHAIN_ROOT}/${NACL_CROSS_PREFIX}
fi

readonly NACL_TOOLCHAIN_PREFIX=${NACL_TOOLCHAIN_INSTALL}/usr

# NACLPORTS_PREFIX is where the headers, libraries, etc. will be installed
# Default to the usr folder within the SDK.
if [ -z "${NACLPORTS_PREFIX:-}" ]; then
  readonly DEFAULT_PREFIX=1
  readonly NACLPORTS_PREFIX=${NACL_TOOLCHAIN_PREFIX}
fi

readonly NACLPORTS_INCLUDE=${NACLPORTS_PREFIX}/include
readonly NACLPORTS_LIBDIR=${NACLPORTS_PREFIX}/lib
readonly NACLPORTS_PREFIX_BIN=${NACLPORTS_PREFIX}/bin

NACLPORTS_CFLAGS=""
NACLPORTS_CXXFLAGS=""
NACLPORTS_CPPFLAGS="${NACL_CPPFLAGS}"

if [ "${DEFAULT_PREFIX:-}" != "1" ]; then
  # If the PREFIX is the default one then there is not need to add
  # the include path explcitily.
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}"
fi

# For the library path we always explicly add to the link flags
# otherwise 'libtool' won't find the libraries correctly.  This
# is because libtool uses 'gcc -print-search-dirs' which does
# not honor the external specs file.
NACLPORTS_LDFLAGS="$NACL_LDFLAGS"
NACLPORTS_LDFLAGS+=" -L${NACLPORTS_LIBDIR} -Wl,-rpath-link=${NACLPORTS_LIBDIR}"

# The NaCl version of ARM gcc emits warnings about va_args that
# are not particularly useful
if [ $NACL_ARCH = "arm" ]; then
  NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS} -Wno-psabi"
  NACLPORTS_CXXFLAGS="${NACLPORTS_CXXFLAGS} -Wno-psabi"
fi

if [ "${NACL_ARCH}" = "emscripten" ]; then
  NACLPORTS_CFLAGS+=" -Wno-warn-absolute-paths"
  NACLPORTS_CXXFLAGS+=" -Wno-warn-absolute-paths"
fi

# configure spec for if MMX/SSE/SSE2/Assembly should be enabled/disabled
# TODO: Currently only x86-32 will encourage MMX, SSE & SSE2 intrinsics
#       and handcoded assembly.
if [ $NACL_ARCH = "i686" ]; then
  readonly NACL_OPTION="enable"
else
  readonly NACL_OPTION="disable"
fi

# As of version 33 the PNaCl C++ standard library is LLVM's libc++,
# others use GCC's libstdc++.
NACL_SDK_VERSION=$(${NACL_SDK_ROOT}/tools/getos.py --sdk-version)
if [ "${NACL_ARCH}" = "pnacl" -a ${NACL_SDK_VERSION} -gt 32 ]; then
  export NACL_CPP_LIB="c++"
else
  export NACL_CPP_LIB="stdc++"
fi

if [ ${NACL_DEBUG} = "1" ]; then
  NACLPORTS_CFLAGS+=" -g -O0"
  NACLPORTS_CXXFLAGS+=" -g -O0"
else
  NACLPORTS_CFLAGS+=" -O2"
  NACLPORTS_CXXFLAGS+=" -O2"
  if [ ${NACL_ARCH} = "pnacl" ]; then
    NACLPORTS_LDFLAGS+=" -O2"
  fi
fi

# libcli_main.a has a circular dependency which makes static link fail
# (cli_main => nacl_io => ppapi_cpp => cli_main). To break this loop,
# you should use this instead of -lcli_main.
export NACL_CLI_MAIN_LIB="-Wl,--undefined=PSUserCreateInstance -lcli_main"

# packages subdirectories
readonly NACL_PACKAGES_OUT=${NACL_SRC}/out
REPOSITORY=${NACL_PACKAGES_OUT}/repository
NACL_BUILD_SUBDIR=build-nacl-${NACL_ARCH}

if [ ${NACL_ARCH} != "pnacl" ]; then
  NACL_BUILD_SUBDIR+=-${NACL_LIBC}
fi

if [ ${NACL_DEBUG} = "1" ]; then
  NACL_BUILD_SUBDIR+=-debug
fi

# Don't support building with SDKs older than the current stable release
MIN_SDK_VERSION=${MIN_SDK_VERSION:-31}

readonly NACL_PACKAGES_REPOSITORY=${REPOSITORY}
readonly NACL_PACKAGES_PUBLISH=${NACL_PACKAGES_OUT}/publish
readonly NACL_PACKAGES_TARBALLS=${NACL_PACKAGES_OUT}/tarballs
readonly NACL_PACKAGES_STAMPDIR=${NACL_PACKAGES_OUT}/stamp

if [ $OS_NAME = "Darwin" ]; then
  OS_JOBS=4
elif [ $OS_NAME = "Linux" ]; then
  OS_JOBS=`nproc`
else
  OS_JOBS=1
fi

GomaTest() {
  # test the goma compiler
  if [ "${NACL_GOMA_FORCE:-}" = 1 ]; then
    return 0
  fi
  echo 'int foo = 4;' > goma_test.c
  GOMA_USE_LOCAL=false GOMA_FALLBACK=false gomacc $1 -c \
      goma_test.c -o goma_test.o 2> /dev/null
  local RTN=$?
  rm -f goma_test.c
  rm -f goma_test.o
  return $RTN
}

# If NACL_GOMA is defined then we check for goma and use it if its found.
if [ -n "${NACL_GOMA:-}" ]; then
  if [ ${NACL_ARCH} != "pnacl" -a ${NACL_ARCH} != "arm" ]; then
    # Assume that if CC is good then so is CXX since GomaTest is actually
    # quite slow
    if GomaTest ${NACLCC}; then
      NACLCC="gomacc ${NACLCC}"
      NACLCXX="gomacc ${NACLCXX}"
      # There is a bug in goma right now where the i686 compiler wrapper script
      # is not correcly handled and gets confiused with the x86_64 version.
      # We need to pass a redunant -m32, to force it to compiler for i686.
      if [ "$NACL_ARCH" = "i686" ]; then
        NACLPORTS_CFLAGS+=" -m32"
        NACLPORTS_CXXFLAGS+=" -m32"
      fi
      OS_JOBS=100
      echo "Using GOMA!"
    fi
  fi
fi

if [ "${NACL_DEBUG}" = "1" ]; then
  NACL_CONFIG=Debug
else
  NACL_CONFIG=Release
fi

# PACKAGE_DIR (the folder contained within that archive) defaults to
# the PACKAGE_NAME.  Packages with non-standard contents can override
# this before including common.sh
PACKAGE_DIR=${PACKAGE_DIR:-${PACKAGE_NAME:-}}
SRC_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}
DEFAULT_BUILD_DIR=${SRC_DIR}/${NACL_BUILD_SUBDIR}
BUILD_DIR=${NACL_BUILD_DIR:-${DEFAULT_BUILD_DIR}}


PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
if [ "${NACL_ARCH}" = "pnacl" ]; then
  PUBLISH_DIR+=/pnacl
else
  PUBLISH_DIR+=/${NACL_LIBC}
fi

if [ "${NACL_ARCH}" != "pnacl" -a -z "${NACL_SEL_LDR:-}" ]; then
  SKIP_SEL_LDR_TESTS=1
else
  SKIP_SEL_LDR_TESTS=0
fi


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


CheckToolchain() {
  if [ -n "${LIBC:-}" ]; then
    if [ "${LIBC}" == "glibc" ]; then
      if [ "${NACL_GLIBC}" != 1 ]; then
        echo "This package must be built with glibc (\$NACL_GLIBC=1)"
        exit 1
      fi
    elif [ "${LIBC}" == "newlib" ]; then
      if [ "${NACL_GLIBC}" = 1 ]; then
        echo "This package must be built with newlib (\$NACL_GLIBC=0)"
        exit 1
      fi
    fi
  fi
}


InstallConfigSite() {
  CONFIG_SITE=${NACLPORTS_PREFIX}/share/config.site
  mkdir -p ${NACLPORTS_PREFIX}/share
  echo "ac_cv_exeext=${NACL_EXEEXT}" > ${CONFIG_SITE}
}


# When configure checks for system headers is doesn't pass CFLAGS
# to the compiler.  This means that any includes that live in paths added
# with -I are not found.  Here we push the additional newlib headers
# into the toolchain itself from $NACL_SDK_ROOT/include/<toolchain>.
InjectSystemHeaders() {
  if [ "${NACL_GLIBC}" = 1 ]; then
    local TC_INCLUDES=${NACL_SDK_ROOT}/include/glibc
  elif [ "${NACL_ARCH}" = "pnacl" ]; then
    local TC_INCLUDES=${NACL_SDK_ROOT}/include/pnacl
  elif [ "${NACL_ARCH}" = "emscripten" ]; then
    return
  else
    local TC_INCLUDES=${NACL_SDK_ROOT}/include/newlib
  fi

  if [ ! -d ${TC_INCLUDES} ]; then
    return
  fi

  MakeDir ${NACL_TOOLCHAIN_PREFIX}/include
  LogExecute cp -r ${TC_INCLUDES}/* ${NACL_TOOLCHAIN_PREFIX}/include
}


PatchSpecFile() {
  if [ "${NACL_ARCH}" = "pnacl" -o "${NACL_ARCH}" = "arm" -o \
       "${NACL_ARCH}" = "emscripten" ]; then
    # The arm compiler doesn't currently need a patched specs file
    # as it ships with the correct paths.  As does the pnacl toolchain.
    return
  fi

  # SPECS_FILE is where nacl-gcc 'specs' file will be installed
  local SPECS_FILE=${NACL_TOOLCHAIN_ROOT}/lib/gcc/x86_64-nacl/4.4.3/specs

  # NACL_SDK_MULITARCH_USR is a version of NACLPORTS_PREFIX that gets passed into
  # the gcc specs file.  It has a gcc spec-file conditional for ${NACL_ARCH}
  local NACL_SDK_MULTIARCH_USR=${NACL_TOOLCHAIN_ROOT}/\%\(nacl_arch\)/usr
  local NACL_SDK_MULTIARCH_USR_INCLUDE=${NACL_SDK_MULTIARCH_USR}/include
  local NACL_SDK_MULTIARCH_USR_LIB=${NACL_SDK_MULTIARCH_USR}/lib
  local ERROR_MSG="Shared libraries are not supported by newlib toolchain"

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
      s|$| -rpath-link=${SED_SAFE_SPACES_USR_LIB} -L${SED_SAFE_SPACES_USR_LIB}|
    }" > ${SPECS_FILE}

  # For newlib toolchain, modify the specs file to give an error when attempting
  # to create a shared object.
  if [ ${NACL_GLIBC} != 1 ]; then
    sed -i.bak "s/%{shared:-shared/%{shared:%e${ERROR_MSG}/" "${SPECS_FILE}"
  fi
}


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


######################################################################
# Helper functions
######################################################################

Banner() {
  echo "######################################################################"
  echo $*
  echo "######################################################################"
}


# echo a command to stdout and then execute it.
LogExecute() {
  echo $*
  $*
}


# Set the ARCHIVE_NAME variable to the nacl of the upstream
# tarball.  If ${URL} is not define (when there is no upstream)
# then leave ARCHIVE_NAME unset.
ArchiveName() {
  if [ -z "${ARCHIVE_NAME:-}" -a -n "${URL:-}" ]; then
    ARCHIVE_NAME=${URL_FILENAME:-$(basename ${URL})}
  fi
}

# Is this a git repo?
IsGitRepo() {
  if [ -z "${URL:-}" ]; then
    return 1;
  fi

  local GIT_URL=${URL%@*}

  if [[ "${#GIT_URL}" -ge "4" ]] && [[ "${GIT_URL:(-4)}" == ".git" ]]; then
    return 0;
  else
    return 1;
  fi
}


#
# Attempt to download a file from a given URL
# $1 - URL to fetch
# $2 - Filename to write to.
#
TryFetch() {
  local URL=$1
  local FILENAME=$2
  Banner "Fetching ${PACKAGE_NAME} (${FILENAME})"
  if which curl > /dev/null ; then
    curl --fail --location --progress-bar -o ${FILENAME} ${URL}
  else
    Banner "ERROR: could not find 'curl' in your PATH"
    exit 1
  fi
}


#
# Download a file from a given URL
# $1 - URL to fetch
# $2 - Filename to write to.
#
Fetch() {
  local URL=$1
  local FILENAME=$2
  local MIRROR_URL=http://storage.googleapis.com/naclports/mirror
  if echo ${URL} | grep -qv http://storage.googleapis.com &> /dev/null; then
    set +o errexit
    # Try mirrored version first
    local BASENAME=${URL_FILENAME:-$(basename ${URL})}
    TryFetch ${MIRROR_URL}/${BASENAME} ${FILENAME}
    if [ $? != 0 -a ${FORCE_MIRROR:-no} = "no" ]; then
      # Fall back to original URL
      TryFetch ${URL} ${FILENAME}
    fi
    set -o errexit
  else
    # The URL is already on Google Clound Storage do just download it
    TryFetch ${URL} ${FILENAME}
  fi

  if [ ! -s ${FILENAME} ]; then
    echo "ERROR: could not find ${FILENAME}"
    exit -1
  fi
}


Check() {
  # verify sha1 checksum for tarball
  local IN_FILE=${START_DIR}/${PACKAGE_NAME}.sha1

  if echo "${SHA1} *${ARCHIVE_NAME}" | ${SHA1CHECK}; then
    return 0
  else
    return 1
  fi
}


DefaultDownloadStep() {
  if [ -z "${ARCHIVE_NAME:-}" ]; then
    return
  fi

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


GitCloneStep() {
  if CheckKeyStamp clone "$URL" ; then
    Banner "Skipping git clone step"
    return
  fi

  local GIT_URL=${URL%@*}
  local COMMIT=${URL#*@}

  Remove ${SRC_DIR}
  git clone ${GIT_URL} ${SRC_DIR}
  ChangeDir ${SRC_DIR}
  git reset --hard ${COMMIT}

  TouchKeyStamp clone "$URL"
}


Patch() {
  local LOCAL_PATCH_FILE=$1
  if [ -e "${START_DIR}/${LOCAL_PATCH_FILE}" ]; then
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
    echo "chdir ${NAME}"
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


DefaultPreInstallStep() {
  cd ${NACL_NATIVE_CLIENT_SDK}/..
  MakeDir ${NACLPORTS_PREFIX}
  MakeDir ${NACLPORTS_INCLUDE}
  MakeDir ${NACLPORTS_LIBDIR}
  MakeDir ${NACL_PACKAGES_REPOSITORY}
  MakeDir ${NACL_PACKAGES_TARBALLS}
  MakeDir ${NACL_PACKAGES_PUBLISH}
}


InitGitRepo() {
  if [ -d .git ]; then
    local PREEXISTING_REPO=1
  else
    local PREEXISTING_REPO=0
  fi

  if [ ${PREEXISTING_REPO} = 0 ]; then
    git init
  fi

  # Setup git username and email in case there is not a system
  # wide one already (git will error out on commit if it is missing).
  if [ -n "${BUILDBOT_BUILDERNAME:-}" ]; then
    if [ -z "$(git config user.email)" ]; then
      git config user.email "naclports_buildbot"
    fi
    if [ -z "$(git config user.name)" ]; then
      git config user.name "naclports buildbot"
    fi
  fi

  # Ignore the nacl build directories so that are preserved
  # across calls to git clean.
  echo "/build-nacl-*" >> .gitignore

  # Ensure that the repo has an upstream and a master branch properly set up.
  if [ ${PREEXISTING_REPO} = 1 ]; then
    git checkout -b "placeholder"
    git show-ref "refs/heads/upstream" > /dev/null && git branch -D "upstream"
    git checkout -b "upstream"
    git show-ref "refs/heads/master" > /dev/null && git branch -D "master"
    git checkout -b "master"
    git branch -D "placeholder"
  else
    git checkout -b "upstream"
    git add -f .
    git commit -m "Upstream version" > /dev/null
    git checkout -b "master"
  fi
}


CheckStamp() {
  local STAMP_DIR="${NACL_PACKAGES_STAMPDIR}/${PACKAGE_NAME}"
  local STAMP_FILE="${STAMP_DIR}/$1"
  # check the stamp file exists and is newer and dependency
  if [ ! -f "${STAMP_FILE}" ]; then
    return 1
  fi
  shift
  while (( "$#" )) ; do
    if [ "$1" -nt "${STAMP_FILE}" ]; then
      return 1
    fi
    shift
  done
  return 0
}


TouchStamp() {
  local STAMP_DIR=${NACL_PACKAGES_STAMPDIR}/${PACKAGE_NAME}
  mkdir -p ${STAMP_DIR}
  touch ${STAMP_DIR}/$1
}


#
# KeyStamp: just like a stamp, but it puts a value in the file
# and checks to make sure it's the same when you check it.
# The value must be the second argument, subsequent arguments
# can be dependencies, just like stamp.
#
CheckKeyStamp() {
  local STAMP_DIR="${NACL_PACKAGES_STAMPDIR}/${PACKAGE_NAME}"
  local STAMP_FILE="${STAMP_DIR}/$1"
  # check the stamp file exists, contains the key, and is newer
  # than dependencies.
  if [ ! -f "${STAMP_FILE}" ]; then
    return 1
  fi

  if [ ! `cat ${STAMP_FILE}` = $2 ]; then
    return 1
  fi

  shift
  shift
  while (( "$#" )) ; do
    if [ "$1" -nt "${STAMP_FILE}" ]; then
      return 1
    fi
    shift
  done
  return 0
}


TouchKeyStamp() {
  local STAMP_DIR=${NACL_PACKAGES_STAMPDIR}/${PACKAGE_NAME}
  mkdir -p ${STAMP_DIR}
  echo $2 > ${STAMP_DIR}/$1
}


InstallNaClTerm() {
  local INSTALL_DIR=$1
  local CHROMEAPPS=${NACL_SRC}/third_party/hterm/src
  local LIB_DOT=${CHROMEAPPS}/libdot
  local NASSH=${CHROMEAPPS}/nassh
  LIBDOT_SEARCH_PATH=${CHROMEAPPS} ${LIB_DOT}/bin/concat.sh \
      -i ${NASSH}/concat/nassh_deps.concat \
      -o ${INSTALL_DIR}/hterm.concat.js

  if [ ${NACL_ARCH} = "pnacl" ] ; then
    sed 's/x-nacl/x-pnacl/' \
        ${TOOLS_DIR}/naclterm.js > ${INSTALL_DIR}/naclterm.js
  else
    LogExecute cp ${TOOLS_DIR}/naclterm.js ${INSTALL_DIR}
  fi
}


#
# Build step for projects based on the NaCl SDK build
# system (common.mk).
#
SetupSDKBuildSystem() {
  # We override $(OUTBASE) to force the build system to put
  # all its artifacts in ${SRC_DIR} rather than alongside
  # the Makefile.
  export OUTBASE=${SRC_DIR}
  export CFLAGS="${NACLPORTS_CPPFLAGS} ${NACLPORTS_CFLAGS}"
  export CXXFLAGS="${NACLPORTS_CPPFLAGS} ${NACLPORTS_CXXFLAGS}"
  export LDFLAGS=${NACLPORTS_LDFLAGS}
  export NACLPORTS_INCLUDE
  export NACLPORTS_PREFIX
  export NACL_PACKAGES_PUBLISH
  export NACL_SRC

  if [ "${NACL_ARCH}" = "pnacl" ]; then
    MAKEFLAGS+=" TOOLCHAIN=pnacl"
  elif [ "${NACL_GLIBC}" = "1" ]; then
    MAKEFLAGS+=" TOOLCHAIN=glibc"
    MAKEFLAGS+=" NACL_ARCH=${NACL_ARCH_ALT}"
  else
    MAKEFLAGS+=" TOOLCHAIN=newlib"
    MAKEFLAGS+=" NACL_ARCH=${NACL_ARCH_ALT}"
  fi
  if [ "${NACL_DEBUG}" = "1" ]; then
    MAKEFLAGS+=" CONFIG=Debug"
  else
    MAKEFLAGS+=" CONFIG=Release"
  fi
  if [ "${VERBOSE:-}" = "1" ]; then
    MAKEFLAGS+=" V=1"
  fi
  export MAKEFLAGS

  BUILD_DIR=${START_DIR}
}


SetupCrossEnvironment() {
  # export the nacl tools
  export CONFIG_SITE
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export READELF=${NACLREADELF}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export FREETYPE_CONFIG=${NACLPORTS_PREFIX_BIN}/freetype-config
  export CFLAGS=${NACLPORTS_CFLAGS}
  export CPPFLAGS=${NACLPORTS_CPPFLAGS}
  export CXXFLAGS=${NACLPORTS_CXXFLAGS}
  export LDFLAGS=${NACLPORTS_LDFLAGS}
  export PATH=${NACL_BIN_PATH}:${NACLPORTS_PREFIX_BIN}:${PATH}
}


######################################################################
# Build Steps
######################################################################
DefaultExtractStep() {
  if [ -z "${ARCHIVE_NAME:-}" ]; then
    return
  fi

  local ARCHIVE="${NACL_PACKAGES_TARBALLS}/${ARCHIVE_NAME}"
  if [ -d ${SRC_DIR} ]; then
    local PATCH="${START_DIR}/${PATCH_FILE:-nacl.patch}"

    if CheckStamp extract "${ARCHIVE}" "${PATCH}" ; then
      Banner "Skipping extract step"
      return
    fi
  fi

  Banner "Extracting ${ARCHIVE_NAME}"
  if [ -d ${SRC_DIR} ]; then
    echo "Upstream archive or patch has changed."
    echo "Please remove existing workspace to continue: '${SRC_DIR}'"
    exit 1
  fi
  Remove ${SRC_DIR}

  # make sure the patch step is applied
  rm -f ${NACL_PACKAGES_STAMPDIR}/${PACKAGE_NAME}/patch
  local EXTENSION="${ARCHIVE_NAME##*.}"
  ChangeDir $(dirname ${SRC_DIR})
  if [ ${EXTENSION} = "zip" ]; then
    unzip ${ARCHIVE}
  else
    if [ $OS_SUBDIR = "win" ]; then
      tar --no-same-owner -xf ${ARCHIVE}
    else
      tar xf ${ARCHIVE}
    fi
  fi

  MakeDir ${BUILD_DIR}
  TouchStamp extract
}


PatchConfigSub() {
  # Replace the package's config.sub one with an up-do-date copy
  # that includes nacl support.  We only do this if the string
  # 'nacl)' is not already contained in the file.
  local CONFIG_SUB=${CONFIG_SUB:-config.sub}
  if [ -f $CONFIG_SUB ]; then
    if grep -q 'nacl)' $CONFIG_SUB /dev/null; then
      echo "$CONFIG_SUB supports NaCl"
    else
      echo "Patching config.sub"
      /bin/cp -f ${TOOLS_DIR}/config.sub $CONFIG_SUB
    fi
  fi
}


PatchConfigure() {
  if [ -f configure ]; then
    Banner "Patching configure"
    ${TOOLS_DIR}/patch_configure.py configure
  fi
}


DefaultPatchStep() {
  if [ -z "${ARCHIVE_NAME:-}" ] && ! IsGitRepo; then
    return
  fi

  ChangeDir ${SRC_DIR}

  if CheckStamp patch ; then
    Banner "Skipping patch step (cleaning source tree)"
    git clean -f -d
    return
  fi

  InitGitRepo
  Patch ${PATCH_FILE:-nacl.patch}
  PatchConfigure
  PatchConfigSub
  if [ -n "$(git diff)" ]; then
    git add -u
    git commit -m "Automatic patch generated by naclports"
  fi

  TouchStamp patch
}


DefaultConfigureStep() {
  local CONFIGURE=${NACL_CONFIGURE_PATH:-${SRC_DIR}/configure}
  if [ -f "${CONFIGURE}" ]; then
    ConfigureStep_Autotools
  elif [ -f "${SRC_DIR}/CMakeLists.txt" ]; then
    ConfigureStep_CMake
  else
    echo "No configure or CMakeLists.txt script found in ${SRC_DIR}"
  fi
}


ConfigureStep_Autotools() {
  SetupCrossEnvironment

  local CONFIGURE=${NACL_CONFIGURE_PATH:-${SRC_DIR}/configure}
  local conf_host=${NACL_CROSS_PREFIX}
  if [ "${NACL_ARCH}" = "pnacl" -o "${NACL_ARCH}" = "emscripten" ]; then
    # The PNaCl tools use "pnacl-" as the prefix, but config.sub
    # does not know about "pnacl".  It only knows about "le32-nacl".
    # Unfortunately, most of the config.subs here are so old that
    # it doesn't know about that "le32" either.  So we just say "nacl".
    conf_host="nacl"
  fi

  if [ -n "${CONFIGURE_SENTINEL:-}" -a -f "${CONFIGURE_SENTINEL:-}" ]; then
    return
  fi

  echo "CPPFLAGS=${CPPFLAGS}"
  echo "CFLAGS=${CFLAGS}"
  echo "CXXFLAGS=${CXXFLAGS}"
  echo "LDFLAGS=${LDFLAGS}"
  LogExecute ${CONFIGURE} \
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
    --with-x=no \
    ${EXTRA_CONFIGURE_ARGS:-}
}


ConfigureStep_CMake() {
  if [ "${VERBOSE:-}" = "1" ]; then
    MAKE_TARGETS+=" VERBOSE=1"
  fi

  EXTRA_CMAKE_ARGS=${EXTRA_CMAKE_ARGS:-}
  if [ "${NACL_GLIBC}" != "1" ]; then
    EXTRA_CMAKE_ARGS+=" -DEXTRA_INCLUDE=${NACLPORTS_INCLUDE}/glibc-compat"
  fi

  CC="${NACLCC}" CXX="${NACLCXX}" LogExecute cmake ..\
           -DCMAKE_TOOLCHAIN_FILE=${TOOLS_DIR}/XCompile-nacl.cmake \
           -DNACLAR=${NACLAR} \
           -DNACLLD=${NACLLD} \
           -DNACL_CROSS_PREFIX=${NACL_CROSS_PREFIX} \
           -DNACL_SDK_ROOT=${NACL_SDK_ROOT} \
           -DNACL_TOOLCHAIN_ROOT=${NACL_TOOLCHAIN_ROOT} \
           -DCMAKE_INSTALL_PREFIX=${NACLPORTS_PREFIX} \
           -DCMAKE_BUILD_TYPE=RELEASE ${EXTRA_CMAKE_ARGS:-}
}


DefaultBuildStep() {
  # Build ${MAKE_TARGETS} or default target if it is not defined
  if [ -n "${MAKEFLAGS:-}" ]; then
    echo "MAKEFLAGS=${MAKEFLAGS}"
    export MAKEFLAGS
  fi
  if [ "${VERBOSE:-}" = "1" ]; then
    MAKE_TARGETS+=" VERBOSE=1 V=1"
  fi
  export PATH=${NACL_BIN_PATH}:${PATH}
  LogExecute make -j${OS_JOBS} ${MAKE_TARGETS:-}
}


DefaultTestStep() {
  echo "No tests defined for ${PACKAGE_NAME}"
}


DefaultInstallStep() {
  # assumes pwd has makefile
  if [ -n "${MAKEFLAGS:-}" ]; then
    echo "MAKEFLAGS=${MAKEFLAGS}"
    export MAKEFLAGS
  fi
  export PATH=${NACL_BIN_PATH}:${PATH}
  LogExecute make ${INSTALL_TARGETS:-install}
}


#
# echo a command before exexuting it under 'time'
#
TimeCommand() {
  echo "$@"
  time "$@"
}


#
# Validate a given NaCl executable (.nexe file)
# $1 - Execuatable file (.nexe)
#
Validate() {
  if [ "${NACL_ARCH}" = "pnacl" -o "${NACL_ARCH}" = "emscripten" ]; then
    return
  fi

  # new SDKs have a single validator called ncval whereas older (<= 28)
  # have a different validator for each arch.
  if [ -f ${NACL_SDK_ROOT}/tools/ncval ]; then
    NACL_VALIDATE=${NACL_SDK_ROOT}/tools/ncval
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


#
# PostBuildStep by default will validae (using ncval) any executables
# specified in the $EXECUTABLES as well as create wrapper scripts
# for running them in sel_ldr.
#
DefaultPostBuildStep() {
  if [ "${NACL_ARCH}" = "emscripten" ]; then
    return;
  fi

  if [ -z "${EXECUTABLES:-}" ]; then
    return
  fi

  if [ "${NACL_ARCH}" = "pnacl" ]; then
    for pexe in ${EXECUTABLES} ; do
      FinalizePexe ${pexe}
    done
    for pexe in ${EXECUTABLES} ; do
      TranslatePexe ${pexe}
    done
    return
  fi

  for nexe in $EXECUTABLES ; do
    Validate ${nexe}
    # Create a script which will run the executable in sel_ldr.  The name
    # of the script is the same as the name of the executable, either without
    # any extension or with the .sh extension.
    if [[ ${nexe} == *${NACL_EXEEXT} && ! -d ${nexe%%${NACL_EXEEXT}} ]]; then
      WriteSelLdrScript ${nexe%%${NACL_EXEEXT}} $(basename ${nexe})
    else
      WriteSelLdrScript $nexe.sh $(basename ${nexe})
    fi
  done
}


#
# Run an executable with under sel_ldr.
# $1 - Executable (.nexe) name
#
RunSelLdrCommand() {
  if [ "${SKIP_SEL_LDR_TESTS}" = "1" ]; then
    return
  fi

  if [ "${NACL_ARCH}" = "pnacl" ]; then
    # For PNaCl we translate to each arch where we have sel_ldr, then run it.
    local PEXE=$1
    local NEXE_32=$1_32.nexe
    local NEXE_64=$1_64.nexe
    local SCRIPT_32=$1_32.sh
    local SCRIPT_64=$1_64.sh
    shift
    TranslateAndWriteSelLdrScript ${PEXE} x86-32 ${NEXE_32} ${SCRIPT_32}
    echo "[sel_ldr x86-32] $@"
    time ./${SCRIPT_32} $*
    if [ -f ${NACL_SEL_LDR_X8664} ]; then
      TranslateAndWriteSelLdrScript ${PEXE} x86-64 ${NEXE_64} ${SCRIPT_64}
      echo "[sel_ldr x86-64] $@"
      time ./${SCRIPT_64} $*
    else
      echo "WARNING: ${NACL_SEL_LDR_X8664} not found, skipping tests."
    fi
  else
    # Normal NaCl.
    local NEXE=$(basename $1)
    local SCRIPT=$1.sh
    if [ -f ${NACL_SEL_LDR} ]; then
      WriteSelLdrScript ${SCRIPT} ${NEXE}
      echo "[sel_ldr] $@"
      shift
      time ./${SCRIPT} $*
    else
      echo "WARNING: ${NACL_SEL_LDR} not found, skipping tests."
    fi
  fi
}


#
# Write a wrapper script that will run a nexe under sel_ldr
# $1 - Script name
# $2 - Nexe name
#
WriteSelLdrScript() {
  if [ "${SKIP_SEL_LDR_TESTS}" = "1" ]; then
    return
  fi

  if [ $NACL_GLIBC = "1" ]; then
    cat > $1 <<HERE
#!/bin/bash
export NACLLOG=/dev/null

SCRIPT_DIR=\$(dirname "\${BASH_SOURCE[0]}")
SEL_LDR=${NACL_SEL_LDR}
IRT=${NACL_IRT}
NACL_SDK_LIB=${NACL_SDK_LIB}
LIB_PATH_DEFAULT=${NACL_SDK_LIBDIR}:${NACLPORTS_LIBDIR}
LIB_PATH_DEFAULT=\${LIB_PATH_DEFAULT}:\${NACL_SDK_LIB}:\${SCRIPT_DIR}
SEL_LDR_LIB_PATH=\${SEL_LDR_LIB_PATH}:\${LIB_PATH_DEFAULT}

"\${SEL_LDR}" -a -B "\${IRT}" -- \\
    "\${NACL_SDK_LIB}/runnable-ld.so" --library-path "\${SEL_LDR_LIB_PATH}" \\
    "\${SCRIPT_DIR}/$2" "\$@"
HERE
  else
    cat > $1 <<HERE
#!/bin/bash
export NACLLOG=/dev/null

SCRIPT_DIR=\$(dirname "\${BASH_SOURCE[0]}")
SEL_LDR=${NACL_SEL_LDR}
IRT=${NACL_IRT}

"\${SEL_LDR}" -a -B "\${IRT}" -- "\${SCRIPT_DIR}/$2" "\$@"
HERE
  fi
  chmod 750 $1
  echo "Wrote script $1 -> $2"
}


TranslateAndWriteSelLdrScript() {
  local PEXE=$1
  local PEXE_FINAL=$1_final.pexe
  local ARCH=$2
  local NEXE=$3
  local SCRIPT=$4
  # Finalize the pexe to make sure it is finalizeable.
  TimeCommand ${PNACLFINALIZE} ${PEXE} -o ${PEXE_FINAL}
  # Translate to the appropriate version.
  TimeCommand ${TRANSLATOR} ${PEXE_FINAL} -arch ${ARCH} -o ${NEXE}
  WriteSelLdrScriptForPNaCl ${SCRIPT} ${NEXE} ${ARCH}
}


#
# Write a wrapper script that will run a nexe under sel_ldr, for PNaCl
# $1 - Script name
# $2 - Nexe name
# $3 - sel_ldr architecture
#
WriteSelLdrScriptForPNaCl() {
  local script_name=$1
  local nexe_name=$2
  local arch=$3
  local nacl_sel_ldr="no-sel-ldr"
  local irt_core="no-irt-core"
  case ${arch} in
    x86-32)
      nacl_sel_ldr=${NACL_SEL_LDR_X8632}
      irt_core=${NACL_IRT_X8632}
      ;;
    x86-64)
      nacl_sel_ldr=${NACL_SEL_LDR_X8664}
      irt_core=${NACL_IRT_X8664}
      ;;
    *)
      echo "No sel_ldr for ${arch}"
      exit 1
  esac
  cat > ${script_name} <<HERE
#!/bin/bash
export NACLLOG=/dev/null

SCRIPT_DIR=\$(dirname "\${BASH_SOURCE[0]}")
SEL_LDR=${nacl_sel_ldr}
IRT=${irt_core}

"\${SEL_LDR}" -a -B "\${IRT}" -- "\${SCRIPT_DIR}/${nexe_name}" "\$@"
HERE
  chmod 750 ${script_name}
  echo "Wrote script $PWD/${script_name}"
}


FinalizePexe() {
  local pexe=$1
  Banner "Finalizing ${pexe}"
  TimeCommand ${PNACLFINALIZE} ${pexe}
}


#
# Translate a PNaCl executable (.pexe) into one or more
# native NaCl executables (.nexe).
# $1 - pexe file
#
TranslatePexe() {
  local pexe=$1
  local basename="${pexe%.*}"
  local arches="arm x86-32 x86-64"
  Banner "Translating ${pexe}"

  for a in ${arches} ; do
    echo "translating pexe [$a]"
    nexe=${basename}.$a.nexe
    TimeCommand ${TRANSLATOR} -O0 -arch $a ${pexe} -o ${nexe}
  done

  # Now the same spiel with -O2

  for a in ${arches} ; do
    echo "translating pexe [$a]"
    nexe=${basename}.opt.$a.nexe
    TimeCommand ${TRANSLATOR} -O2 -arch $a ${pexe} -o ${nexe}
  done

  ls -l $(dirname ${pexe})/*.nexe ${pexe}
}


DefaultPackageInstall() {
  RunPreInstallStep
  if IsGitRepo; then
    RunGitCloneStep
  else
    RunDownloadStep
    RunExtractStep
  fi
  RunPatchStep
  RunConfigureStep
  RunBuildStep
  RunPostBuildStep
  RunTestStep
  RunInstallStep
}


NaclportsMain() {
  local COMMAND=PackageInstall
  if [[ $# -gt 0 ]]; then
    COMMAND=Run$1
  fi
  if [ -d "${BUILD_DIR}" ]; then
    ChangeDir ${BUILD_DIR}
  fi
  ${COMMAND}
}


RunStep() {
  local STEP_FUNCTION=$1
  local DIR=''
  shift
  if [ $# -gt 0 ]; then
    local TITLE=$1
    shift
    Banner "${TITLE} ${PACKAGE_NAME}"
  fi
  if [ $# -gt 0 ]; then
    DIR=$1
    shift
  fi
  if [ -n "${DIR}" ]; then
    if [ ! -d ${DIR} ]; then
      MakeDir ${DIR}
    fi
    ChangeDir ${DIR}
  fi
  ArchiveName
  # Step functions are run in sub-shell so that they are independent
  # from each other.
  ( ${STEP_FUNCTION} )
}


# Function entry points that packages should override in order
# to customize the build process.
PreInstallStep() { DefaultPreInstallStep; }
DownloadStep()   { DefaultDownloadStep;   }
ExtractStep()    { DefaultExtractStep;    }
PatchStep()      { DefaultPatchStep;      }
ConfigureStep()  { DefaultConfigureStep;  }
BuildStep()      { DefaultBuildStep;      }
PostBuildStep()  { DefaultPostBuildStep;  }
TestStep()       { DefaultTestStep;       }
InstallStep()    { DefaultInstallStep;    }
PackageInstall() { DefaultPackageInstall; }

RunPreInstallStep() { RunStep PreInstallStep; }
RunDownloadStep()   { RunStep DownloadStep; }
RunGitCloneStep()   { RunStep GitCloneStep; }
RunExtractStep()    { RunStep ExtractStep; }
RunPatchStep()      { RunStep PatchStep; }
RunConfigureStep()  {
  RunStep ConfigureStep "Configuring" ${BUILD_DIR};
}
RunBuildStep()      { RunStep BuildStep "Building" ${BUILD_DIR}; }
RunPostBuildStep()  { RunStep PostBuildStep "PostBuild" ${BUILD_DIR}; }
RunTestStep()       {
  if [ "${SKIP_SEL_LDR_TESTS}" = "1" ]; then
    return;
  fi
  RunStep TestStep "Testing" ${BUILD_DIR}
}
RunInstallStep()    { RunStep InstallStep "Installing" ${BUILD_DIR}; }

######################################################################
# Always run
# These functions are called when this script is imported to do
# any essential checking/setup operations.
######################################################################
CheckToolchain
CheckPatchVersion
CheckSDKVersion
PatchSpecFile
InjectSystemHeaders
InstallConfigSite
