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

. ${SCRIPT_DIR}/nacl_env.sh

# When run by a buildbot force all archives to come from the NaCl mirror
# rather than using upstream URL.
if [ -n ${BUILDBOT_BUILDERNAME:-""} ]; then
  FORCE_MIRROR=${FORCE_MIRROR:-"yes"}
fi

# sha1check python script
readonly SHA1CHECK=${SCRIPT_DIR}/sha1check.py

readonly NACLPORTS_INCLUDE=${NACLPORTS_PREFIX}/include
readonly NACLPORTS_LIBDIR=${NACLPORTS_PREFIX}/lib
readonly NACLPORTS_PREFIX_BIN=${NACLPORTS_PREFIX}/bin

NACLPORTS_CFLAGS="-I${NACLPORTS_INCLUDE} ${NACL_CFLAGS}"
NACLPORTS_CXXFLAGS="-I${NACLPORTS_INCLUDE} ${NACL_CXXFLAGS}"
NACLPORTS_LDFLAGS="-L${NACLPORTS_LIBDIR} ${NACL_LDFLAGS}"

# The NaCl version of ARM gcc emits warnings about va_args that
# are not particularly useful
if [ $NACL_ARCH = "arm" ]; then
  NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS} -Wno-psabi"
  NACLPORTS_CXXFLAGS="${NACLPORTS_CXXFLAGS} -Wno-psabi"
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
if [ ${NACL_DEBUG} = "1" ]; then
  NACLPORTS_CFLAGS="${NACLPORTS_CFLAGS} -g -O0"
  NACLPORTS_CXXFLAGS="${NACLPORTS_CXXFLAGS} -g -O0"
fi

# packages subdirectories
readonly NACL_PACKAGES_LIBRARIES=${NACL_PACKAGES}/libraries
readonly NACL_PACKAGES_OUT=${NACL_SRC}/out
REPOSITORY=${NACL_PACKAGES_OUT}/repository
NACL_BUILD_SUBDIR=build-nacl-${NACL_ARCH}-${NACL_LIBC}
if [ ${NACL_DEBUG} = "1" ]; then
  NACL_BUILD_SUBDIR=${NACL_BUILD_SUBDIR}-debug
fi
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

export CFLAGS=${NACLPORTS_CFLAGS}
export CXXFLAGS=${NACLPORTS_CXXFLAGS}
export LDFLAGS=${NACLPORTS_LDFLAGS}

NACL_CREATE_NMF_FLAGS="-L${NACL_TOOLCHAIN_ROOT}/x86_64-nacl/usr/lib \
-L${NACL_TOOLCHAIN_ROOT}/i686-nacl/usr/lib
-L${NACL_TOOLCHAIN_ROOT}/x86_64-nacl/lib64 \
-L${NACL_TOOLCHAIN_ROOT}/x86_64-nacl/lib32 \
-L${NACL_SDK_ROOT}/lib/glibc_x86_64/Release \
-L${NACL_SDK_ROOT}/lib/glibc_x86_32/Release \
-D${NACL_BIN_PATH}/x86_64-nacl-objdump"

# PACKAGE_DIR (the folder contained within that archive) defaults to
# the PACKAGE_NAME.  Packages with non-standard contents can override
# this before including common.sh
PACKAGE_DIR=${PACKAGE_DIR:-${PACKAGE_NAME:-}}


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
    curl --fail --location --url $1 -o $2
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
}


InitGitRepo() {
  if [ -d .git ]; then
    # Strangely one of the upstream archives (x264) actually contains a full
    # .git repo already. In this case we remove it completely and re-initialise
    # a new git repo.  TODO(sbc): remove this once x264 is updated.
    rm -rf .git .gitignore
  fi
  git init

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
  git checkout -b "upstream"
  git add .
  git commit -m "Upstream version" > /dev/null
  git checkout -b "master"
}


DefaultCleanStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  Remove ${PACKAGE_DIR}
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


DefaultExtractStep() {
  ArchiveName

  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  local ARCHIVE="${NACL_PACKAGES_TARBALLS}/${ARCHIVE_NAME}"
  if [ -d ${PACKAGE_DIR} ]; then
    local PATCH="${START_DIR}/${PATCH_FILE:-nacl.patch}"

    if CheckStamp extract "${ARCHIVE}" "${PATCH}" ; then
      Banner "Skipping extract step"
      return
    fi
  fi

  Banner "Extracting ${ARCHIVE_NAME}"

  # make sure the patch step is applied
  rm -f ${NACL_PACKAGES_STAMPDIR}/${PACKAGE_NAME}/patch
  Remove ${PACKAGE_DIR}
  local EXTENSION="${ARCHIVE_NAME##*.}"
  if [ ${EXTENSION} = "zip" ]; then
    unzip ${ARCHIVE}
  else
    if [ $OS_SUBDIR = "win" ]; then
      tar --no-same-owner -xf ${ARCHIVE}
    else
      tar xf ${ARCHIVE}
    fi
  fi

  TouchStamp extract
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

  if CheckStamp patch ; then
     Banner "Skipping patch step"
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
  MakeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/${NACL_BUILD_SUBDIR}
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_DIR}/${NACL_BUILD_SUBDIR}
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
  # Build ${MAKE_TARGETS} or default target if it is not defined
  echo "MAKEFLAGS=${MAKEFLAGS}"
  export MAKEFLAGS
  LogExecute make -j${OS_JOBS} ${MAKE_TARGETS:-}
}


DefaultInstallStep() {
  Banner "Installing"
  # assumes pwd has makefile
  echo "MAKEFLAGS=${MAKEFLAGS}"
  export MAKEFLAGS
  LogExecute make ${INSTALL_TARGETS:-install}
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
