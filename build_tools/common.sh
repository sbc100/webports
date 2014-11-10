# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Environment variable NACL_ARCH should be set to one of the following
# values: i686 x86_64 pnacl arm


# NAMING CONVENTION
# =================
#
# This file is source'd by the main naclports build script.  Functions
# and variables defined here are available in the build script for
# individual ports.  Only variables beginging with "NACL_" are intended
# to be used by those scripts.

set -o nounset
set -o errexit

unset MAKEFLAGS

readonly TOOLS_DIR=$(cd "$(dirname "${BASH_SOURCE}")" ; pwd)
readonly START_DIR=${PWD}
readonly NACL_SRC=$(dirname "${TOOLS_DIR}")
readonly NACL_PACKAGES=${NACL_SRC}

NACL_DEBUG=${NACL_DEBUG:-0}

NACL_ENV_IMPORT=1
. "${TOOLS_DIR}/nacl-env.sh"

# When run by a buildbot force all archives to come from the NaCl mirror
# rather than using upstream URL.
if [ -n "${BUILDBOT_BUILDERNAME:-}" ]; then
  FORCE_MIRROR=${FORCE_MIRROR:-"yes"}
fi

# sha1check python script
readonly SHA1CHECK=${TOOLS_DIR}/sha1check.py

readonly NACLPORTS_INCLUDE=${NACL_PREFIX}/include
readonly NACLPORTS_LIBDIR=${NACL_PREFIX}/lib
readonly NACLPORTS_BIN=${NACL_PREFIX}/bin

# The prefix used when configuring packages.  Since we want to build re-usable
# re-locatable binary packages, we use a dummy value here and then modify
# at install time certain parts of package (e.g. pkgconfig .pc files) that
# embed this this information.
readonly PREFIX=/naclports-dummydir

NACLPORTS_CFLAGS=""
NACLPORTS_CXXFLAGS=""
NACLPORTS_CPPFLAGS="${NACL_CPPFLAGS}"

# For the library path we always explicly add to the link flags
# otherwise 'libtool' won't find the libraries correctly.  This
# is because libtool uses 'gcc -print-search-dirs' which does
# not honor the external specs file.
NACLPORTS_LDFLAGS="${NACL_LDFLAGS}"
NACLPORTS_LDFLAGS+=" -L${NACLPORTS_LIBDIR} -Wl,-rpath-link=${NACLPORTS_LIBDIR}"

# The NaCl version of ARM gcc emits warnings about va_args that
# are not particularly useful
if [ "${NACL_ARCH}" = "arm" ]; then
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
if [ "${NACL_ARCH}" = "i686" ]; then
  readonly NACL_OPTION="enable"
else
  readonly NACL_OPTION="disable"
fi

# Set NACL_SHARED when we want to build shared libraries.
if [ "${NACL_LIBC}" = "glibc" -o "${NACL_LIBC}" = "bionic" ]; then
  NACL_SHARED=1
else
  NACL_SHARED=0
fi

if [ "${NACL_DEBUG}" = "1" ]; then
  NACLPORTS_CFLAGS+=" -g -O0"
  NACLPORTS_CXXFLAGS+=" -g -O0"
else
  NACLPORTS_CFLAGS+=" -O2"
  NACLPORTS_CXXFLAGS+=" -O2"
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    NACLPORTS_LDFLAGS+=" -O2"
  fi
fi

# libcli_main.a has a circular dependency which makes static link fail
# (cli_main => nacl_io => ppapi_cpp => cli_main). To break this loop,
# you should use this instead of -lcli_main.
export NACL_CLI_MAIN_LIB="-Wl,-uPSUserCreateInstance -lcli_main"

# Python variables
NACL_PYSETUP_ARGS=""
NACL_BUILD_SUBDIR=build
NACL_INSTALL_SUBDIR=install

# output directories
readonly NACL_PACKAGES_OUT=${NACL_SRC}/out
readonly NACL_PACKAGES_ROOT=${NACL_PACKAGES_OUT}/packages
readonly NACL_PACKAGES_BUILD=${NACL_PACKAGES_OUT}/build
readonly NACL_PACKAGES_PUBLISH=${NACL_PACKAGES_OUT}/publish
readonly NACL_PACKAGES_CACHE=${NACL_PACKAGES_OUT}/cache
readonly NACL_PACKAGES_STAMPDIR=${NACL_PACKAGES_OUT}/stamp
readonly NACL_HOST_PYROOT=${NACL_PACKAGES_BUILD}/python-host/install_host
readonly NACL_HOST_PYBUILD=${NACL_PACKAGES_BUILD}/python-host/build_host
readonly NACL_HOST_PYTHON=${NACL_HOST_PYROOT}/bin/python2.7
readonly NACL_DEST_PYROOT=${NACL_PREFIX}
readonly SITE_PACKAGES="lib/python2.7/site-packages/"

# The components of package names cannot contain underscore
# characters so use x86-64 rather then x86_64 for arch component.
if [ "${NACL_ARCH}" = "x86_64" ]; then
  PACKAGE_SUFFIX="_x86-64"
else
  PACKAGE_SUFFIX="_${NACL_ARCH}"
fi

if [ "${NACL_ARCH}" != "pnacl" ]; then
  PACKAGE_SUFFIX+=_${NACL_LIBC}
fi

if [ "${NACL_DEBUG}" = "1" ]; then
  PACKAGE_SUFFIX+=_debug
fi

NACL_BUILD_SUBDIR+=${PACKAGE_SUFFIX}
NACL_INSTALL_SUBDIR+=${PACKAGE_SUFFIX}
readonly DEST_PYTHON_OBJS=${NACL_PACKAGES_BUILD}/python-modules/${NACL_BUILD_SUBDIR}
PACKAGE_FILE=${NACL_PACKAGES_ROOT}/${NAME}_${VERSION}${PACKAGE_SUFFIX}.tar.bz2
PATCH_FILE=${START_DIR}/nacl.patch

# Don't support building with SDKs older than the current stable release
MIN_SDK_VERSION=${MIN_SDK_VERSION:-37}

if [ "${OS_NAME}" = "Darwin" ]; then
  OS_JOBS=4
elif [ "${OS_NAME}" = "Linux" ]; then
  OS_JOBS=$(nproc)
else
  OS_JOBS=1
fi

GomaTest() {
  # test the goma compiler
  if [ "${NACL_GOMA_FORCE:-}" = 1 ]; then
    return 0
  fi
  echo 'int foo = 4;' > goma_test.c
  GOMA_USE_LOCAL=false GOMA_FALLBACK=false gomacc "$1" -c \
      goma_test.c -o goma_test.o 2> /dev/null
  local RTN=$?
  rm -f goma_test.c
  rm -f goma_test.o
  return ${RTN}
}

# If NACL_GOMA is defined then we check for goma and use it if its found.
if [ -n "${NACL_GOMA:-}" ]; then
  if [ "${NACL_ARCH}" != "pnacl" -a "${NACL_ARCH}" != "arm" ]; then
    # Assume that if CC is good then so is CXX since GomaTest is actually
    # quite slow
    if GomaTest "${NACLCC}"; then
      NACLCC="gomacc ${NACLCC}"
      NACLCXX="gomacc ${NACLCXX}"
      # There is a bug in goma right now where the i686 compiler wrapper script
      # is not correcly handled and gets confiused with the x86_64 version.
      # We need to pass a redunant -m32, to force it to compiler for i686.
      if [ "${NACL_ARCH}" = "i686" ]; then
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

# ARCHIVE_ROOT (the folder contained within that archive) defaults to
# the NAME-VERSION.  Packages with non-standard contents can override
# this before including common.sh
PACKAGE_NAME=${NAME}
ARCHIVE_ROOT=${ARCHIVE_ROOT:-${NAME}-${VERSION}}
WORK_DIR=${NACL_PACKAGES_BUILD}/${NAME}
SRC_DIR=${WORK_DIR}/${ARCHIVE_ROOT}
DEFAULT_BUILD_DIR=${WORK_DIR}/${NACL_BUILD_SUBDIR}
BUILD_DIR=${NACL_BUILD_DIR:-${DEFAULT_BUILD_DIR}}
INSTALL_DIR=${WORK_DIR}/${NACL_INSTALL_SUBDIR}

# DESTDIR is where the headers, libraries, etc. will be installed
# Default to the usr folder within the SDK.
if [ -z "${DESTDIR:-}" ]; then
  readonly DEFAULT_DESTDIR=1
  DESTDIR=${INSTALL_DIR}
fi

DESTDIR_LIB=${DESTDIR}/${PREFIX}/lib
DESTDIR_INCLUDE=${DESTDIR}/${PREFIX}/include

PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
if [ "${NACL_ARCH}" = "pnacl" ]; then
  PUBLISH_DIR+=/pnacl
else
  PUBLISH_DIR+=/${NACL_LIBC}
fi

SKIP_SEL_LDR_TESTS=0

# Skip sel_ldr tests when building for arm
if [ "${NACL_ARCH}" = "arm" ]; then
  SKIP_SEL_LDR_TESTS=1
fi

# Skip sel_ldr tests when building x86_64 targets on a 32-bit host
if [ "${NACL_ARCH}" = "x86_64" -a "${HOST_IS_32BIT}" = "1" ]; then
  echo "WARNING: Building x86_64 targets on i686 host. Cannot run tests."
  SKIP_SEL_LDR_TESTS=1
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
  if [ "$(patch --version 2> /dev/null | sed q)" = "patch 2.6" ]; then
    echo "patch 2.6 is incompatible with these scripts."
    echo "Please install either version 2.5.9 (or earlier)"
    echo "or version 2.6.1 (or later.)"
    exit -1
  fi
}


CheckToolchain() {
  if [ -n "${LIBC:-}" ]; then
    if [ "${LIBC}" == "glibc" ]; then
      if [ "${NACL_LIBC}" != "glibc" ]; then
        echo "This package must be built with glibc (\$TOOLCHAIN=glibc)"
        exit 1
      fi
    elif [ "${LIBC}" == "newlib" ]; then
      if [ "${NACL_LIBC}" != "newlib" ]; then
        echo "This package must be built with newlib (\$TOOLCHAIN=newlib)"
        exit 1
      fi
    fi
  fi
}


InstallConfigSite() {
  CONFIG_SITE=${NACL_PREFIX}/share/config.site
  MakeDir "${NACL_PREFIX}/share"
  echo "ac_cv_exeext=${NACL_EXEEXT}" > "${CONFIG_SITE}"
}


# When configure checks for system headers is doesn't pass CFLAGS
# to the compiler.  This means that any includes that live in paths added
# with -I are not found.  Here we push the additional newlib headers
# into the toolchain itself from ${NACL_SDK_ROOT}/include/<toolchain>.
InjectSystemHeaders() {
  local TC_INCLUDES=${NACL_SDK_ROOT}/include/${TOOLCHAIN}
  if [ ! -d "${TC_INCLUDES}" ]; then
    return
  fi

  MakeDir ${NACLPORTS_INCLUDE}
  for inc in $(find ${TC_INCLUDES} -type f); do
    inc="${inc#${TC_INCLUDES}}"
    src="${TC_INCLUDES}${inc}"
    dest="${NACLPORTS_INCLUDE}${inc}"
    if [ -f "${dest}" ]; then
      if cmp "${src}" "${dest}" > /dev/null; then
        continue
      fi
    fi
    MakeDir "$(dirname ${dest})"
    LogExecute install -m 644 "${src}" "${dest}"
  done
}


PatchSpecsFile() {
  if [ "${NACL_ARCH}" = "pnacl" -o \
       "${NACL_ARCH}" = "emscripten" ]; then
    # The emscripten and PNaCl toolchains already include the required
    # include and library paths by defaut. No need to patch them.
    return
  fi

  # SPECS_FILE is where nacl-gcc 'specs' file will be installed
  local SPECS_DIR=
  if [ "${NACL_ARCH}" = "arm" ]; then
    SPECS_DIR=${NACL_TOOLCHAIN_ROOT}/lib/gcc/arm-nacl/4.8.2
    if [ ! -d "${SPECS_DIR}" ]; then
      SPECS_DIR=${NACL_TOOLCHAIN_ROOT}/lib/gcc/arm-nacl/4.8.3
    fi
  else
    SPECS_DIR=${NACL_TOOLCHAIN_ROOT}/lib/gcc/x86_64-nacl/4.4.3
  fi
  local SPECS_FILE=${SPECS_DIR}/specs

  # NACL_SDK_MULITARCH_USR is a version of NACL_TOOLCHAIN_ROOT that gets passed
  # into the gcc specs file.  It has a gcc spec-file conditional for
  # ${NACL_ARCH}
  local NACL_SDK_MULTIARCH_USR="${NACL_TOOLCHAIN_ROOT}/\%\(nacl_arch\)/usr"
  local NACL_SDK_MULTIARCH_USR_INCLUDE="${NACL_SDK_MULTIARCH_USR}/include"
  local NACL_SDK_MULTIARCH_USR_LIB="${NACL_SDK_MULTIARCH_USR}/lib"
  local ERROR_MSG="Shared libraries are not supported by newlib toolchain"

  # fix up spaces so gcc sees entire path
  local SED_SAFE_SPACES_USR_INCLUDE=${NACL_SDK_MULTIARCH_USR_INCLUDE/ /\ /}
  local SED_SAFE_SPACES_USR_LIB=${NACL_SDK_MULTIARCH_USR_LIB/ /\ /}

  if [ -f ${SPECS_FILE} ]; then
    if grep -q "${NACL_SDK_MULTIARCH_USR_LIB}" ${SPECS_FILE}; then
      echo "Specs file already patched"
      return
    fi
    echo "Patching existing specs file"
    cp ${SPECS_FILE} ${SPECS_FILE}.current
  else
    echo "Creating new specs file"
    ${NACLCC} -dumpspecs > ${SPECS_FILE}.current
  fi

  # add include & lib search paths to specs file
  if [ "${NACL_ARCH}" = "arm" ]; then
    local ARCH_SUBST='/\*cpp:/ {
        printf("*nacl_arch:\narm-nacl\n\n", $1); }
        { print $0; }'
  else
    local ARCH_SUBST='/\*cpp:/ {
        printf("*nacl_arch:\n%%{m64:x86_64-nacl; m32:i686-nacl; :x86_64-nacl}\n\n", $1); }
        { print $0; }'
  fi

  awk "${ARCH_SUBST}" < ${SPECS_FILE}.current |\
    sed "/*cpp:/{
      N
      s|$| -isystem ${SED_SAFE_SPACES_USR_INCLUDE}|
    }" |\
    sed "/*link_libgcc:/{
      N
      s|$| -rpath-link=${SED_SAFE_SPACES_USR_LIB} -L${SED_SAFE_SPACES_USR_LIB}|
    }" > "${SPECS_FILE}"

  # For static-only toolchains (i.e. newlib), modify the specs file to give an
  # error when attempting to create a shared object.
  if [ "${NACL_SHARED}" != "1" ]; then
    sed -i.bak "s/%{shared:-shared/%{shared:%e${ERROR_MSG}/" "${SPECS_FILE}"
  fi
}


CheckSDKVersion() {
  if [ -z "${MIN_SDK_VERSION:-}" ]; then
    return
  fi
  local GETOS=${NACL_SDK_ROOT}/tools/getos.py
  local RESULT=$("${GETOS}" --check-version="${MIN_SDK_VERSION}" 2>&1)
  if [ -n "${RESULT:-}" ]; then
    echo "The SDK in \$NACL_SDK_ROOT is too old to build ${PACKAGE_NAME}."
    echo "${RESULT}"
    exit -1
  fi
}


######################################################################
# Helper functions
######################################################################

Banner() {
  echo "######################################################################"
  echo "$@"
  echo "######################################################################"
}


# echo a command to stdout and then execute it.
LogExecute() {
  echo "$@"
  "$@"
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
  # Send curl's status messages to stdout rather then stderr
  CURL_ARGS="--fail --location --stderr -"
  if [ -t 1 ]; then
    # Add --progress-bar but only if stdout is a TTY device.
    CURL_ARGS+=" --progress-bar"
  else
    # otherwise suppress all status output, since curl always
    # assumes a TTY and writes \r and \b characters.
    CURL_ARGS+=" --silent"
  fi
  if which curl > /dev/null ; then
    curl ${CURL_ARGS} -o "${FILENAME}" "${URL}"
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
    TryFetch "${MIRROR_URL}/${BASENAME}" "${FILENAME}"
    if [ $? != 0 -a ${FORCE_MIRROR:-no} = "no" ]; then
      # Fall back to original URL
      TryFetch "${URL}" "${FILENAME}"
    fi
    set -o errexit
  else
    # The URL is already on Google Clound Storage do just download it
    TryFetch "${URL}" "${FILENAME}"
  fi

  if [ ! -s "${FILENAME}" ]; then
    echo "ERROR: failed to download ${FILENAME}"
    exit -1
  fi
}


Check() {
  # verify sha1 checksum for tarball
  if echo "${SHA1} *${ARCHIVE_NAME}" | "${SHA1CHECK}"; then
    return 0
  else
    return 1
  fi
}


DefaultDownloadStep() {
  if [ -z "${ARCHIVE_NAME:-}" ]; then
    return
  fi

  cd "${NACL_PACKAGES_CACHE}"
  # if matching tarball already exists, don't download again
  if ! Check ; then
    Fetch "${URL}" "${ARCHIVE_NAME}"
    if ! Check ; then
       Banner "${PACKAGE_NAME} failed checksum!"
       exit -1
    fi
  fi
}


GitCloneStep() {
  local stamp_content="GITURL=${URL}"
  if [ -f "${PATCH_FILE}" ]; then
    local patch_checksum=$(${TOOLS_DIR}/sha1sum.py "${PATCH_FILE}")
    stamp_content+=" PATCH_${patch_checksum}"
  fi

  if [ -d "${SRC_DIR}" ]; then
    if CheckStampContent clone "${stamp_content}" ; then
      Banner "Skipping git clone step"
      return
    fi

    echo "Upstream archive or patch has changed."
    echo "Please remove existing checkout to continue: '${SRC_DIR}'"
    exit 1
  fi

  local GIT_URL=${URL%@*}
  local COMMIT=${URL#*@}

  # Clone upstream git repo into local mirror, or update the existing
  # mirror.
  local GIT_MIRROR=${GIT_URL##*://}
  GIT_MIRROR=${GIT_MIRROR//\//_}
  cd "${NACL_PACKAGES_CACHE}"
  if [ -e "${GIT_MIRROR}" ]; then
    cd "${GIT_MIRROR}"
    if git rev-parse "${COMMIT}" > /dev/null 2>&1; then
      echo "git mirror up-to-date: ${GIT_MIRROR}"
    else
      echo "Updating git mirror: ${GIT_MIRROR}"
      LogExecute git remote update --prune
    fi
    cd "${NACL_PACKAGES_CACHE}"
  else
    LogExecute git clone --mirror "${GIT_URL}" "${GIT_MIRROR}"
  fi

  # Clone from the local mirror.
  LogExecute git clone "${GIT_MIRROR}" "${SRC_DIR}"
  ChangeDir "${SRC_DIR}"
  LogExecute git reset --hard "${COMMIT}"

  # Set the origing to the original URL so it is possible to push directly
  # from the build tree.
  git remote set-url origin "${GIT_URL}"

  WriteStamp clone "${stamp_content}"

  # make sure the patch step is applied
  Remove "${NACL_PACKAGES_STAMPDIR}/${PACKAGE_NAME}/patch"
}


#
# Apply the package's patch file in the current working directory
#
Patch() {
  if [ -f "${PATCH_FILE}" ]; then
    Banner "Patching $(basename ${PWD})"
    #git apply ${PATCH_FILE}
    patch -p1 -g0 --no-backup-if-mismatch < "${PATCH_FILE}"
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
  local NAME="$1"
  if VerifyPath "${NAME}"; then
    echo "chdir ${NAME}"
    cd "${NAME}"
  else
    echo "ChangeDir called with bad path."
    exit -1
  fi
}


Remove() {
  local NAME="$1"
  if VerifyPath "${NAME}"; then
    rm -rf "${NAME}"
  else
    echo "Remove called with bad path."
    exit -1
  fi
}


MakeDir() {
  local NAME="$1"
  if VerifyPath "${NAME}"; then
    mkdir -p "${NAME}"
  else
    echo "MakeDir called with bad path."
    exit -1
  fi
}


DefaultPreInstallStep() {
  MakeDir "${NACL_PACKAGES_ROOT}"
  MakeDir "${NACL_PACKAGES_BUILD}"
  # If 'tarballs' directory exists then rename it to the new name: 'cache'.
  # TODO(sbc): remove this once the new name as been in existence for
  # a few months.
  if [ ! -d "${NACL_PACKAGES_CACHE}" -a -d "${NACL_PACKAGES_OUT}/tarballs" ]; then
    mv "${NACL_PACKAGES_OUT}/tarballs" "${NACL_PACKAGES_CACHE}"
  fi
  MakeDir "${NACL_PACKAGES_CACHE}"
  MakeDir "${NACL_PACKAGES_PUBLISH}"
  MakeDir "${WORK_DIR}"
}


PublishByArchForDevEnv() {
  MakeDir "${PUBLISH_DIR}"
  local ARCH_DIR=${PUBLISH_DIR}/${NACL_ARCH}
  MakeDir "${ARCH_DIR}"
  # TODO(bradnelson): Drop this once all pors that have executables list them
  # explicitly (required for pnacl to work right anyhow).
  if [ "${EXECUTABLES:-}" != "" ]; then
    local executables="${EXECUTABLES}"
  elif [ "${OS_NAME}" != "Darwin" ]; then
    # -executable is not supported on BSD and -perm +nn is not
    # supported on linux
    local executables=$(find . -type f -executable -not -path "*/.git/*")
  else
    local executables=$(find . -type f -perm +u+x -not -path "*/.git/*")
  fi
  for nexe in ${executables}; do
    local name=$(basename ${nexe})
    name=${name/%.nexe/}
    name=${name/%.pexe/}
    LogExecute cp "${nexe}" "${ARCH_DIR}/${name}"
    # TODO(bradnelson): Do something prettier.
    if [[ "$(head -c 2 ${nexe})" != "#!" && \
          "$(head -c 2 ${nexe})" != "# " && \
          "${nexe}" != *.txt ]]; then
      # Strip non-scripts
      LogExecute "${NACLSTRIP}" "${ARCH_DIR}/${name}"

      # Run create_nmf for non-scripts.
      # Stage libraries for toolchains that support dynamic linking.
      if [[ "${TOOLCHAIN}" = "glibc" || "${TOOLCHAIN}" = "bionic" ]]; then
        pushd "${ARCH_DIR}"
        # Create a temporary name ending in .nexe so create_nmf does the right
        # thing.
        LogExecute cp "${name}" tmp.nexe
        LogExecute python "${NACL_SDK_ROOT}/tools/create_nmf.py" \
          tmp.nexe -s . -o tmp.nmf
        LogExecute rm tmp.nexe
        LogExecute rm tmp.nmf
        popd
      fi
    fi
  done
  ChangeDir "${ARCH_DIR}"
  Remove "${ARCH_DIR}.zip"
  LogExecute zip -r "${ARCH_DIR}.zip" .
}


InitGitRepo() {
  if [ -d .git ]; then
    local PREEXISTING_REPO=1
  else
    local PREEXISTING_REPO=0
  fi

  if [ ${PREEXISTING_REPO} = 0 ]; then
    LogExecute git init
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

  # Ensure that the repo has an upstream and a master branch properly set up.
  if [ ${PREEXISTING_REPO} = 1 ]; then
    git checkout -b placeholder
    git show-ref refs/heads/upstream > /dev/null && git branch -D upstream
    git checkout -b upstream
    git show-ref refs/heads/master > /dev/null && git branch -D master
    git checkout -b master
    git branch -D placeholder
  else
    git add -f .
    git commit -m "Upstream version" > /dev/null
    git checkout -b upstream
    git checkout master
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
  MakeDir "${STAMP_DIR}"
  touch "${STAMP_DIR}/$1"
}


#
# CheckStampContent: checks that a stampfile exists an has a specified contents.
#
# $1 - Name of stamp file.
# $2 - Expected contents of stamp file.
#
CheckStampContent() {
  local STAMP_DIR="${NACL_PACKAGES_STAMPDIR}/${PACKAGE_NAME}"
  local STAMP_FILE="${STAMP_DIR}/$1"

  # check the stamp file exists
  if [ ! -f "${STAMP_FILE}" ]; then
    return 1
  fi

  # check the stamp contents
  local stamp_contents=$(cat "${STAMP_FILE}")
  if [ ! "${stamp_contents}" = "$2" ]; then
    return 1
  fi

  return 0
}


WriteStamp() {
  local STAMP_DIR=${NACL_PACKAGES_STAMPDIR}/${PACKAGE_NAME}
  MakeDir "${STAMP_DIR}"
  echo "$2" > "${STAMP_DIR}/$1"
}


InstallNaClTerm() {
  local INSTALL_DIR=$1
  local CHROMEAPPS=${NACL_SRC}/third_party/libapps/
  local LIB_DOT=${CHROMEAPPS}/libdot
  local HTERM=${CHROMEAPPS}/hterm
  LIBDOT_SEARCH_PATH=${CHROMEAPPS} LogExecute "${LIB_DOT}/bin/concat.sh" \
      -i "${HTERM}/concat/hterm_deps.concat" -o "${INSTALL_DIR}/hterm.concat.js"
  LIBDOT_SEARCH_PATH=${CHROMEAPPS} LogExecute ${LIB_DOT}/bin/concat.sh \
      -i "${HTERM}/concat/hterm.concat" -o "${INSTALL_DIR}/hterm2.js"
  chmod +w "${INSTALL_DIR}/hterm.concat.js" "${INSTALL_DIR}/hterm2.js"
  cat "${INSTALL_DIR}/hterm2.js" >> "${INSTALL_DIR}/hterm.concat.js"
  Remove "${INSTALL_DIR}/hterm2.js"

  LogExecute cp "${TOOLS_DIR}/naclterm.js" "${INSTALL_DIR}"
  LogExecute cp "${TOOLS_DIR}/pipeserver.js" "${INSTALL_DIR}"
  if [ "${NACL_ARCH}" = "pnacl" ] ; then
    sed 's/x-nacl/x-pnacl/' \
        "${TOOLS_DIR}/naclprocess.js" > "${INSTALL_DIR}/naclprocess.js"
  else
    LogExecute cp "${TOOLS_DIR}/naclprocess.js" "${INSTALL_DIR}"
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
  export NACL_PREFIX
  export NACL_PACKAGES_PUBLISH
  export NACL_SRC
  export NACLPORTS_INCLUDE
  export NACLPORTS_REVISION=${REVISION}
  export PKG_CONFIG_LIBDIR="${NACLPORTS_LIBDIR}/pkgconfig"
  export ENABLE_BIONIC=1
  # By default PKG_CONFIG_PATH is set to <libdir>/pkgconfig:<datadir>/pkgconfig.
  # While PKG_CONFIG_LIBDIR overrides <libdir>, <datadir> (/usr/share/) can only
  # be overridden individually when pkg-config is built.
  # Setting PKG_CONFIG_PATH instead to compensate.
  export PKG_CONFIG_PATH="${NACLPORTS_LIBDIR}/pkgconfig"
  PKG_CONFIG_PATH+=":${NACLPORTS_LIBDIR}/../share/pkgconfig"

  MAKEFLAGS+=" TOOLCHAIN=${TOOLCHAIN}"
  MAKEFLAGS+=" NACL_ARCH=${NACL_ARCH_ALT}"
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

SetupCrossPaths() {
  export PKG_CONFIG_LIBDIR="${NACLPORTS_LIBDIR}/pkgconfig"
  # By default PKG_CONFIG_PATH is set to <libdir>/pkgconfig:<datadir>/pkgconfig.
  # While PKG_CONFIG_LIBDIR overrides <libdir>, <datadir> (/usr/share/) can only
  # be overridden individually when pkg-config is built.
  # Setting PKG_CONFIG_PATH instead to compensate.
  export PKG_CONFIG_PATH="${NACLPORTS_LIBDIR}/pkgconfig"
  PKG_CONFIG_PATH+=":${NACLPORTS_LIBDIR}/../share/pkgconfig"
  export SDL_CONFIG=${NACLPORTS_BIN}/sdl-config
  export FREETYPE_CONFIG=${NACLPORTS_BIN}/freetype-config
  export PATH=${NACL_BIN_PATH}:${NACLPORTS_BIN}:${PATH}
}

SetupCrossEnvironment() {
  SetupCrossPaths

  # export the nacl tools
  export CONFIG_SITE
  export EXEEXT=${NACL_EXEEXT}
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export READELF=${NACLREADELF}
  export STRIP=${NACLSTRIP}

  export CFLAGS=${NACLPORTS_CFLAGS}
  export CPPFLAGS=${NACLPORTS_CPPFLAGS}
  export CXXFLAGS=${NACLPORTS_CXXFLAGS}
  export LDFLAGS=${NACLPORTS_LDFLAGS}
  export ARFLAGS=${NACL_ARFLAGS}
  export AR_FLAGS=${NACL_ARFLAGS}

  echo "CPPFLAGS=${CPPFLAGS}"
  echo "CFLAGS=${CFLAGS}"
  echo "CXXFLAGS=${CXXFLAGS}"
  echo "LDFLAGS=${LDFLAGS}"
}


GetRevision() {
  cd ${NACL_SRC}
  FULL_REVISION=$(git describe)
  REVISION=$(echo "${FULL_REVISION}" | cut  -f2 -d-)
  cd - > /dev/null
}


GenerateManifest() {
  local SOURCE_FILE=$1
  shift
  local TARGET_DIR=$1
  shift
  local TEMPLATE_EXPAND="${START_DIR}/../../build_tools/template_expand.py"

  # TODO(sbc): deal with versions greater than 16bit.
  if (( REVISION >= 65536 )); then
    echo "Version too great to store in revision field on manifest.json"
    exit 1
  fi

  if [ $# -gt 0 ]; then
    local KEY="$(cat $1)"
  else
    local KEY=""
  fi
  echo "Expanding ${SOURCE_FILE} > ${TARGET_DIR}/manifest.json"
  # Generate a manifest.json
  "${TEMPLATE_EXPAND}" "${SOURCE_FILE}" \
    version=${REVISION} key="${KEY}" > ${TARGET_DIR}/manifest.json
}


FixupExecutablesList() {
  # Modify EXECUTABLES list for libtool case where actual executables
  # live within the ".libs" folder.
  local executables_modified=
  for nexe in ${EXECUTABLES:-}; do
    local basename=$(basename ${nexe})
    local dirname=$(dirname ${nexe})
    if [ -f "${dirname}/.libs/${basename}" ]; then
      executables_modified+=" ${dirname}/.libs/${basename}"
    else
      executables_modified+=" ${nexe}"
    fi
  done
  EXECUTABLES=${executables_modified}
}


######################################################################
# Build Steps
######################################################################
DefaultExtractStep() {
  if [ -z "${ARCHIVE_NAME:-}" ]; then
    return
  fi

  local stamp_content="ARCHIVE_SHA1=${SHA1}"
  if [ -f "${PATCH_FILE}" ]; then
    local patch_checksum=$(${TOOLS_DIR}/sha1sum.py ${PATCH_FILE})
    stamp_content+=" PATCH_${patch_checksum}"
  fi

  if [ -d "${SRC_DIR}" ]; then
    if CheckStampContent extract "${stamp_content}" ; then
      Banner "Skipping extract step"
      return
    fi
  fi

  Banner "Extracting ${ARCHIVE_NAME}"
  if [ -d "${SRC_DIR}" ]; then
    echo "Upstream archive or patch has changed."
    echo "Please remove existing workspace to continue: '${SRC_DIR}'"
    exit 1
  fi
  Remove "${SRC_DIR}"

  # make sure the patch step is applied
  Remove "${NACL_PACKAGES_STAMPDIR}/${PACKAGE_NAME}/patch"
  local EXTENSION="${ARCHIVE_NAME##*.}"
  PARENT_DIR=$(dirname ${SRC_DIR})
  MakeDir "${PARENT_DIR}"
  ChangeDir "${PARENT_DIR}"
  local ARCHIVE="${NACL_PACKAGES_CACHE}/${ARCHIVE_NAME}"
  if [ "${EXTENSION}" = "zip" ]; then
    LogExecute unzip -q "${ARCHIVE}"
  else
    if [ "${OS_SUBDIR}" = "win" ]; then
      LogExecute tar --no-same-owner -xf "${ARCHIVE}"
    else
      LogExecute tar xf "${ARCHIVE}"
    fi
  fi

  MakeDir "${BUILD_DIR}"
  WriteStamp extract "${stamp_content}"
}


PatchConfigSub() {
  # Replace the package's config.sub one with an up-do-date copy
  # that includes nacl support.  We only do this if the string
  # 'nacl)' is not already contained in the file.
  CONFIG_SUB=${CONFIG_SUB:-config.sub}
  if [ ! -f "${CONFIG_SUB}" ]; then
    CONFIG_SUB=$(find "${SRC_DIR}" -name config.sub -print)
  fi

  for sub in ${CONFIG_SUB}; do
    if grep -q 'nacl)' "${sub}" /dev/null; then
      echo "${CONFIG_SUB} supports NaCl"
    else
      echo "Patching ${sub}"
      /bin/cp -f "${TOOLS_DIR}/config.sub" "${sub}"
    fi
  done
}


PatchConfigure() {
  if [ -f configure ]; then
    Banner "Patching configure"
    "${TOOLS_DIR}/patch_configure.py" configure
  fi
}


DefaultPatchStep() {
  if [ -z "${ARCHIVE_NAME:-}" ] && ! IsGitRepo; then
    return
  fi

  ChangeDir "${SRC_DIR}"

  if CheckStamp patch ; then
    Banner "Skipping patch step (cleaning source tree)"
    git clean -f -d
    return
  fi

  InitGitRepo
  Patch "${PATCH_FILE}"
  PatchConfigure
  PatchConfigSub
  if [ -n "$(git diff --no-ext-diff)" ]; then
    git add -u
    git commit -m "Automatic patch generated by naclports"
  fi

  TouchStamp patch
}


DefaultConfigureStep() {
  local CONFIGURE=${NACL_CONFIGURE_PATH:-${SRC_DIR}/configure}

  if [ "${NACLPORTS_QUICKBUILD:-}" = "1" ]; then
    CONFIGURE_SENTINEL=${CONFIGURE_SENTINEL:-Makefile}
  fi

  if [ -n "${CONFIGURE_SENTINEL:-}" -a -f "${CONFIGURE_SENTINEL:-}" ]; then
    return
  fi

  if [ -f "${CONFIGURE}" ]; then
    ConfigureStep_Autotools
  elif [ -f "${SRC_DIR}/CMakeLists.txt" ]; then
    ConfigureStep_CMake
  else
    echo "No configure or CMakeLists.txt script found in ${SRC_DIR}"
  fi
}


ConfigureStep_Autotools() {
  conf_build=$(/bin/sh "${SCRIPT_DIR}/config.guess")

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

  # Inject a shim that speed up pnacl invocations for configure.
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    local PNACL_CONF_SHIM="${TOOLS_DIR}/pnacl-configure-shim.py"
    CC="${PNACL_CONF_SHIM} ${CC}"
  fi

  # Specify both --build and --host options.  This forces autoconf into cross
  # compile mode.  This is useful since the autodection doesn't always works.
  # For example a trivial PNaCl binary can sometimes run on the linux host if
  # it has the correct LLVM bimfmt support. What is more, autoconf will
  # generate a warning if only --host is specified.
  LogExecute "${CONFIGURE}" \
    --build=${conf_build} \
    --host=${conf_host} \
    --prefix=${PREFIX} \
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
  if [ "${CMAKE_USE_NINJA:-}" = "1" ]; then
    EXTRA_CMAKE_ARGS+=" -GNinja"
  fi

  EXTRA_CMAKE_ARGS=${EXTRA_CMAKE_ARGS:-}
  if [ "${NACL_LIBC}" = "newlib" ]; then
    EXTRA_CMAKE_ARGS+=" -DEXTRA_INCLUDE=${NACLPORTS_INCLUDE}/glibc-compat"
  fi

  if [ $NACL_DEBUG = "1" ]; then
    BUILD_TYPE=DEBUG
  else
    BUILD_TYPE=RELEASE
  fi

  SetupCrossPaths
  LogExecute cmake "${SRC_DIR}" \
           -DCMAKE_TOOLCHAIN_FILE=${TOOLS_DIR}/XCompile-nacl.cmake \
           -DNACLAR=${NACLAR} \
           -DNACLLD=${NACLLD} \
           -DNACLCC=${NACLCC} \
           -DNACLCXX=${NACLCXX} \
           -DNACL_CROSS_PREFIX=${NACL_CROSS_PREFIX} \
           -DNACL_ARCH=${NACL_ARCH} \
           -DNACL_SDK_ROOT=${NACL_SDK_ROOT} \
           -DNACL_SDK_LIBDIR=${NACL_SDK_LIBDIR} \
           -DNACL_TOOLCHAIN_ROOT=${NACL_TOOLCHAIN_ROOT} \
           -DNACL_LIBC=${NACL_LIBC} \
           -DCMAKE_PREFIX_PATH=${NACL_PREFIX} \
           -DCMAKE_INSTALL_PREFIX=${PREFIX} \
           -DCMAKE_BUILD_TYPE=${BUILD_TYPE} ${EXTRA_CMAKE_ARGS}
}


DefaultBuildStep() {
  if [ "${CMAKE_USE_NINJA:-}" = "1" ]; then
    if [ "${VERBOSE:-}" = "1" ]; then
      NINJA_ARGS="-v"
    fi
    LogExecute ninja ${NINJA_ARGS:-} ${MAKE_TARGETS:-}
    return
  fi

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


DefaultPythonModuleBuildStep() {
  SetupCrossEnvironment
  Banner "Build ${PACKAGE_NAME} python module"
  ChangeDir "${SRC_DIR}"
  LogExecute rm -rf build dist
  MakeDir "${NACL_DEST_PYROOT}/${SITE_PACKAGES}"
  export PYTHONPATH="${NACL_HOST_PYROOT}/${SITE_PACKAGES}"
  export PYTHONPATH="${PYTHONPATH}:${NACL_DEST_PYROOT}/${SITE_PACKAGES}"
  export NACL_PORT_BUILD=${1:-dest}
  export NACL_BUILD_TREE=${NACL_DEST_PYROOT}
  export CFLAGS="${NACLPORTS_CPPFLAGS} ${NACLPORTS_CFLAGS}"
  export CXXFLAGS="${NACLPORTS_CPPFLAGS} ${NACLPORTS_CXXFLAGS}"
  export LDFLAGS=${NACLPORTS_LDFLAGS}
  LogExecute "${NACL_HOST_PYTHON}" setup.py \
    ${NACL_PYSETUP_ARGS:-} \
    install "--prefix=${NACL_DEST_PYROOT}"
  MakeDir "${DEST_PYTHON_OBJS}/${PACKAGE_NAME}"
  LogExecute find build -name "*.o" -execdir cp -v {} \
    "${DEST_PYTHON_OBJS}/${PACKAGE_NAME}/"{} \;
}


DefaultTestStep() {
  echo "No tests defined for ${PACKAGE_NAME}"
}


DefaultPostInstallTestStep() {
  echo "No post-packaging tests defined for ${PACKAGE_NAME}"
}


DefaultInstallStep() {
  INSTALL_TARGETS=${INSTALL_TARGETS:-install}

  if [ "${CMAKE_USE_NINJA:-}" = "1" ]; then
    DESTDIR="${DESTDIR}" LogExecute ninja ${INSTALL_TARGETS}
    return
  fi

  # assumes pwd has makefile
  if [ -n "${MAKEFLAGS:-}" ]; then
    echo "MAKEFLAGS=${MAKEFLAGS}"
    export MAKEFLAGS
  fi
  export PATH="${NACL_BIN_PATH}:${PATH}"
  LogExecute make ${INSTALL_TARGETS} "DESTDIR=${DESTDIR}"
}


DefaultPythonModuleInstallStep() {
  Banner "Installing ${PACKAGE_NAME}"
  # We've installed already previously.  We just need to collect our modules.
  MakeDir "${NACL_HOST_PYROOT}/python_modules/"
  if [ -e "${START_DIR}/modules.list" ] ; then
    LogExecute cp "${START_DIR}/modules.list" \
                  "${DEST_PYTHON_OBJS}/${PACKAGE_NAME}.list"
  fi
  if [ -e "${START_DIR}/modules.libs" ] ; then
    LogExecute cp "${START_DIR}/modules.libs" \
                  "${DEST_PYTHON_OBJS}/${PACKAGE_NAME}.libs"
  fi
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
  if [ -f "${NACL_SDK_ROOT}/tools/ncval" ]; then
    NACL_VALIDATE="${NACL_SDK_ROOT}/tools/ncval"
  elif [ "${NACL_ARCH}" = "arm" ]; then
    NACL_VALIDATE="${NACL_SDK_ROOT}/tools/ncval_arm"
  elif [ "${NACL_ARCH}" = "x86_64" ]; then
    NACL_VALIDATE="${NACL_SDK_ROOT}/tools/ncval_x86_64 --errors"
  else
    NACL_VALIDATE="${NACL_SDK_ROOT}/tools/ncval_x86_32"
  fi
  LogExecute "${NACL_VALIDATE}" "$@"
  if [ $? != 0 ]; then
    exit 1
  fi
}


#
# PostBuildStep by default will validae (using ncval) any executables
# specified in the ${EXECUTABLES} as well as create wrapper scripts
# for running them in sel_ldr.
#
DefaultPostBuildStep() {
  if [ "${NACL_ARCH}" = "emscripten" ]; then
    return
  fi

  if [ -z "${EXECUTABLES}" ]; then
    return
  fi

  if [ "${NACL_ARCH}" = "pnacl" ]; then
    for pexe in ${EXECUTABLES}; do
      FinalizePexe "${pexe}"
    done
    if [ "${TRANSLATE_PEXES:-}" != "no" ]; then
      for pexe in ${EXECUTABLES}; do
        TranslatePexe "${pexe}"
      done
    fi
    return
  fi

  for nexe in ${EXECUTABLES}; do
    Validate "${nexe}"
    # Create a script which will run the executable in sel_ldr.  The name
    # of the script is the same as the name of the executable, either without
    # any extension or with the .sh extension.
    if [[ ${nexe} == *${NACL_EXEEXT} && ! -d ${nexe%%${NACL_EXEEXT}} ]]; then
      WriteSelLdrScript "${nexe%%${NACL_EXEEXT}}" "$(basename ${nexe})"
    else
      WriteSelLdrScript "${nexe}.sh" "$(basename ${nexe})"
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
    TranslateAndWriteSelLdrScript "${PEXE}" x86-32 "${NEXE_32}" "${SCRIPT_32}"
    echo "[sel_ldr x86-32] ${SCRIPT_32} $*"
    "./${SCRIPT_32}" "$@"
    TranslateAndWriteSelLdrScript "${PEXE}" x86-64 "${NEXE_64}" "${SCRIPT_64}"
    echo "[sel_ldr x86-64] ${SCRIPT_64} $*"
    "./${SCRIPT_64}" "$@"
  else
    # Normal NaCl.
    local nexe=$1
    local basename=$(basename ${nexe})
    local dirname=$(dirname ${nexe})
    if [ -f "${dirname}/.libs/${basename}" ]; then
      nexe=${dirname}/.libs/${basename}
    fi

    local SCRIPT=${nexe}.sh
    WriteSelLdrScript "${SCRIPT}" ${basename}
    shift
    echo "[sel_ldr] ${SCRIPT} $*"
    "./${SCRIPT}" "$@"
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

  if [ "${OS_NAME}" = "Cygwin" ]; then
    local LOGFILE=nul
    local NACL_IRT_PATH=$(cygpath -m "${NACL_IRT}")
  else
    local LOGFILE=/dev/null
    local NACL_IRT_PATH=${NACL_IRT}
  fi

  if [ "${NACL_LIBC}" = "glibc" ]; then
    cat > "$1" <<HERE
#!/bin/bash
export NACLLOG=${LOGFILE}

SCRIPT_DIR=\$(dirname "\${BASH_SOURCE[0]}")
SEL_LDR=${NACL_SEL_LDR}
IRT=${NACL_IRT_PATH}
NACL_SDK_LIB=${NACL_SDK_LIB}
LIB_PATH_DEFAULT=${NACL_SDK_LIBDIR}:${NACLPORTS_LIBDIR}
LIB_PATH_DEFAULT=\${LIB_PATH_DEFAULT}:\${NACL_SDK_LIB}:\${SCRIPT_DIR}
SEL_LDR_LIB_PATH=\${SEL_LDR_LIB_PATH}:\${LIB_PATH_DEFAULT}

"\${SEL_LDR}" -a -B "\${IRT}" -- \\
    "\${NACL_SDK_LIB}/runnable-ld.so" --library-path "\${SEL_LDR_LIB_PATH}" \\
    "\${SCRIPT_DIR}/$2" "\$@"
HERE
  else
    cat > "$1" <<HERE
#!/bin/bash
export NACLLOG=${LOGFILE}

SCRIPT_DIR=\$(dirname "\${BASH_SOURCE[0]}")
if [ \$(uname -s) = CYGWIN* ]; then
  SCRIPT_DIR=\$(cygpath -m \${SCRIPT_DIR})
fi
SEL_LDR=${NACL_SEL_LDR}
IRT=${NACL_IRT_PATH}

"\${SEL_LDR}" -a -B "\${IRT}" -- "\${SCRIPT_DIR}/$2" "\$@"
HERE
  fi
  chmod 750 "$1"
  echo "Wrote script $1 -> $2"
}


TranslateAndWriteSelLdrScript() {
  local PEXE=$1
  local PEXE_FINAL=$1_final.pexe
  local ARCH=$2
  local NEXE=$3
  local SCRIPT=$4
  # Finalize the pexe to make sure it is finalizeable.
  if [ "${PEXE}" -nt "${PEXE_FINAL}" ]; then
    "${PNACLFINALIZE}" "${PEXE}" -o "${PEXE_FINAL}"
  fi
  # Translate to the appropriate version.
  if [ "${PEXE_FINAL}" -nt "${NEXE}" ]; then
    "${TRANSLATOR}" "${PEXE_FINAL}" -arch "${ARCH}" -o "${NEXE}"
  fi
  WriteSelLdrScriptForPNaCl "${SCRIPT}" $(basename "${NEXE}") "${ARCH}"
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
      nacl_sel_ldr="${NACL_SEL_LDR_X8632}"
      irt_core="${NACL_IRT_X8632}"
      ;;
    x86-64)
      nacl_sel_ldr="${NACL_SEL_LDR_X8664}"
      irt_core="${NACL_IRT_X8664}"
      ;;
    *)
      echo "No sel_ldr for ${arch}"
      exit 1
  esac
  cat > "${script_name}" <<HERE
#!/bin/bash
export NACLLOG=/dev/null

SCRIPT_DIR=\$(dirname "\${BASH_SOURCE[0]}")
SEL_LDR=${nacl_sel_ldr}
IRT=${irt_core}

"\${SEL_LDR}" -a -B "\${IRT}" -- "\${SCRIPT_DIR}/${nexe_name}" "\$@"
HERE
  chmod 750 "${script_name}"
  echo "Wrote script ${PWD}/${script_name}"
}


FinalizePexe() {
  local pexe=$1
  Banner "Finalizing ${pexe}"
  "${PNACLFINALIZE}" "${pexe}"
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
    echo "translating pexe [${a}]"
    nexe=${basename}.${a}.nexe
    if [ "${pexe}" -nt "${nexe}" ]; then
      "${TRANSLATOR}" -O0 -arch "${a}" "${pexe}" -o "${nexe}"
    fi
  done

  # Now the same spiel with -O2

  for a in ${arches} ; do
    echo "translating pexe [${a}]"
    nexe=${basename}.opt.${a}.nexe
    if [ "${pexe}" -nt "${nexe}" ]; then
      "${TRANSLATOR}" -O2 -arch "${a}" "${pexe}" -o "${nexe}"
    fi
  done

  local dirname=$(dirname "${pexe}")
  ls -l "${dirname}"/*.nexe "${pexe}"
}


PackageStep() {
  local basename=$(basename "${PACKAGE_FILE}")
  Banner "Packaging ${basename}"
  if [ -d "${INSTALL_DIR}${PREFIX}" ]; then
    mv "${INSTALL_DIR}${PREFIX}" "${INSTALL_DIR}/payload"
  fi
  local excludes="usr/doc share/man share/info info/
                  share/doc lib/charset.alias"
  for exclude in ${excludes}; do
    if [ -e "${INSTALL_DIR}/payload/${exclude}" ]; then
      echo "Pruning ${exclude}"
      rm -rf "${INSTALL_DIR}/payload/${exclude}"
    fi
  done
  LogExecute cp "${START_DIR}/pkg_info" "${INSTALL_DIR}"
  if [ "${NACL_DEBUG}" = "1" ]; then
    echo "BUILD_CONFIG=debug" >> "${INSTALL_DIR}/pkg_info"
  else
    echo "BUILD_CONFIG=release" >> "${INSTALL_DIR}/pkg_info"
  fi
  echo "BUILD_ARCH=${NACL_ARCH}" >> "${INSTALL_DIR}/pkg_info"
  echo "BUILD_TOOLCHAIN=${TOOLCHAIN}" >> "${INSTALL_DIR}/pkg_info"
  echo "BUILD_SDK_VERSION=${NACL_SDK_VERSION}" >> "${INSTALL_DIR}/pkg_info"
  echo "BUILD_NACLPORTS_REVISION=${FULL_REVISION}" >> "${INSTALL_DIR}/pkg_info"
  if [ "${OS_NAME}" = "Darwin" ]; then
    # OSX likes to create files starting with ._. We don't want to package
    # these.
    local args="--exclude ._*"
  else
    local args=""
  fi
  # Create packge in temporary location and move into place once
  # done.  This prevents partially created packages from being
  # left lying around if this process is interrupted.
  LogExecute tar cjf "${PACKAGE_FILE}.tmp" -C "${INSTALL_DIR}" ${args} .
  LogExecute mv -f "${PACKAGE_FILE}.tmp" "${PACKAGE_FILE}"
}


ZipPublishDir() {
  # If something exists in the publish directory, zip it for download by mingn.
  if [ "${NACLPORTS_QUICKBUILD:-}" = "1" ]; then
    return
  fi
  if [ -d "${PUBLISH_DIR}" ]; then
    # Remove existing zip as it may contain only some architectures.
    LogExecute rm -f "${PUBLISH_DIR}.zip"
    pushd "${PUBLISH_DIR}"
    LogExecute zip -rq "${PUBLISH_DIR}.zip" ./
    popd
  fi
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
  RunPostInstallTestStep
  ZipPublishDir
  PackageStep
}


NaclportsMain() {
  local COMMAND=PackageInstall
  if [[ $# -gt 0 ]]; then
    COMMAND=Run$1
  fi
  if [ -d "${BUILD_DIR}" ]; then
    ChangeDir "${BUILD_DIR}"
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
    if [ ! -d "${DIR}" ]; then
      MakeDir "${DIR}"
    fi
    ChangeDir "${DIR}"
  fi
  ArchiveName
  # Step functions are run in sub-shell so that they are independent
  # from each other.
  ( ${STEP_FUNCTION} )
}


# Function entry points that packages should override in order
# to customize the build process.
PreInstallStep()      { DefaultPreInstallStep;      }
DownloadStep()        { DefaultDownloadStep;        }
ExtractStep()         { DefaultExtractStep;         }
PatchStep()           { DefaultPatchStep;           }
ConfigureStep()       { DefaultConfigureStep;       }
BuildStep()           { DefaultBuildStep;           }
PostBuildStep()       { DefaultPostBuildStep;       }
TestStep()            { DefaultTestStep;            }
InstallStep()         { DefaultInstallStep;         }
PostInstallTestStep() { DefaultPostInstallTestStep; }
PackageInstall()      { DefaultPackageInstall;      }

RunPreInstallStep() { RunStep PreInstallStep; }
RunDownloadStep()   { RunStep DownloadStep; }
RunGitCloneStep()   { RunStep GitCloneStep; }
RunExtractStep()    { RunStep ExtractStep; }
RunPatchStep()      { RunStep PatchStep; }


RunConfigureStep()  {
  RunStep ConfigureStep "Configuring" "${BUILD_DIR}"
}


RunBuildStep()      {
  RunStep BuildStep "Building" "${BUILD_DIR}"
  FixupExecutablesList
}


RunPostBuildStep()  {
  RunStep PostBuildStep "PostBuild" "${BUILD_DIR}"
}


RunTestStep()       {
  if [ "${SKIP_SEL_LDR_TESTS}" = "1" ]; then
    return
  fi
  if [ "${NACLPORTS_QUICKBUILD:-}" = "1" ]; then
    return
  fi
  RunStep TestStep "Testing" "${BUILD_DIR}"
}


RunPostInstallTestStep()       {
  if [ "${NACLPORTS_QUICKBUILD:-}" = "1" ]; then
    return
  fi
  RunStep PostInstallTestStep "Testing (post-install)"
}


RunInstallStep()    {
  Remove "${INSTALL_DIR}"
  MakeDir "${INSTALL_DIR}"
  RunStep InstallStep "Installing" "${BUILD_DIR}"
}


######################################################################
# Always run
# These functions are called when this script is imported to do
# any essential checking/setup operations.
######################################################################
CheckToolchain
CheckPatchVersion
CheckSDKVersion
PatchSpecsFile
InjectSystemHeaders
InstallConfigSite
GetRevision
