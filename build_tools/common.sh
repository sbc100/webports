# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Environment variable NACL_PACKAGES_BITSIZE should be unset or set to "32"
# for a 32-bit build.  It should be set to "64" for a 64-bit build.

set -o nounset
set -o errexit

# Scripts that source this file must be run from within the naclports src tree.
# Note that default build steps reference the packages directory.
readonly SAVE_PWD=$(pwd)

readonly START_DIR=$(cd "$(dirname "$0")" ; pwd)
readonly NACL_SRC=`expr ${START_DIR} : '\(.*\/src\).*'`
readonly NACL_PACKAGES=${NACL_SRC}/packages
readonly NACL_NATIVE_CLIENT_SDK=$(cd $NACL_SRC ; pwd)

# Pick platform directory for compiler.
readonly OS_NAME=$(uname -s)
if [ $OS_NAME = "Darwin" ]; then
  readonly OS_SUBDIR="mac"
  readonly OS_SUBDIR_SHORT="mac"
  readonly OS_JOBS=4
elif [ $OS_NAME = "Linux" ]; then
  readonly OS_SUBDIR="linux"
  readonly OS_SUBDIR_SHORT="linux"
  readonly OS_JOBS=4
else
  readonly OS_SUBDIR="windows"
  readonly OS_SUBDIR_SHORT="win"
  readonly OS_JOBS=1
fi

# Get the desired bit size.
readonly NACL_PACKAGES_BITSIZE=${NACL_PACKAGES_BITSIZE:-"32"}
if [ $NACL_PACKAGES_BITSIZE = "32" ] ; then
  readonly NACL_BIT_SPEC=""
elif [ $NACL_PACKAGES_BITSIZE = "64" ] ; then
  readonly NACL_BIT_SPEC="64"
else
  echo "Unknown value for NACL_PACKAGES_BITSIZE: '$NACL_PACKAGES_BITSIZE'" 1>&2
  exit 1
fi

readonly CROSS_ID=${NACL_BIT_SPEC}
readonly NACL_CROSS_PREFIX=nacl${CROSS_ID}
readonly NACL_CROSS_PREFIX_DASH=${NACL_CROSS_PREFIX}-

# configure spec for if MMX/SSE/SSE2/Assembly should be enabled/disabled
# TODO: Currently only x86-32 will encourage MMX, SSE & SSE2 intrinsics
#       and handcoded assembly.
if [ $NACL_PACKAGES_BITSIZE = "32" ] ; then
  readonly NACL_OPTION="enable"
else
  readonly NACL_OPTION="disable"
fi

# locate default nacl_sdk toolchain
# TODO: x86 only at the moment
readonly NACL_TOP=$(cd $NACL_NATIVE_CLIENT_SDK/.. ; pwd)
readonly NACL_NATIVE_CLIENT=${NACL_TOP}/native_client
readonly NACL_TOOLCHAIN_ROOT=${NACL_TOOLCHAIN_ROOT:-\
${NACL_SDK_ROOT}/toolchain/${OS_SUBDIR_SHORT}_x86}
readonly NACL_SDK_BASE=${NACL_SDK_BASE:-${NACL_TOOLCHAIN_ROOT}}

# packages subdirectories
readonly NACL_PACKAGES_SCRIPTS=${NACL_PACKAGES}/scripts
readonly NACL_PACKAGES_OUT=${NACL_PACKAGES}/out
readonly NACL_PACKAGES_REPOSITORY=${NACL_PACKAGES_OUT}/repository${CROSS_ID}
readonly NACL_PACKAGES_PUBLISH=${NACL_PACKAGES_OUT}/publish${CROSS_ID}
readonly NACL_PACKAGES_TARBALLS=${NACL_PACKAGES_OUT}/tarballs

# sha1check python script
readonly SHA1CHECK=${NACL_PACKAGES_SCRIPTS}/sha1check.py

readonly NACL_BIN_PATH=${NACL_TOOLCHAIN_ROOT}/bin
readonly NACLCC=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX_DASH}gcc
readonly NACLCXX=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX_DASH}g++
readonly NACLAR=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX_DASH}ar
readonly NACLRANLIB=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX_DASH}ranlib
readonly NACLLD=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX_DASH}ld


# NACL_SDK_GCC_SPECS_PATH is where nacl-gcc 'specs' file will be installed
readonly NACL_SDK_GCC_SPECS_PATH=\
${NACL_TOOLCHAIN_ROOT}/lib/gcc/x86_64-nacl/4.4.3

# NACL_SDK_USR is where the headers, libraries, etc. will be installed
readonly NACL_SDK_USR=${NACL_TOOLCHAIN_ROOT}/${NACL_CROSS_PREFIX}/usr
readonly NACL_SDK_USR_INCLUDE=${NACL_SDK_USR}/include
readonly NACL_SDK_USR_LIB=${NACL_SDK_USR}/lib

# NACL_SDK_MULITARCH_USR is a version of NACL_SDK_USR that gets passed into
# the gcc specs file.  It has a gcc spec-file conditional for ${CROSS_ID}
readonly NACL_SDK_MULTIARCH_USR=${NACL_TOOLCHAIN_ROOT}/\%\(nacl_arch\)/usr
readonly NACL_SDK_MULTIARCH_USR_INCLUDE=${NACL_SDK_MULTIARCH_USR}/include
readonly NACL_SDK_MULTIARCH_USR_LIB=${NACL_SDK_MULTIARCH_USR}/lib

######################################################################
# Always run
######################################################################

CheckPatchVersion() {
  # refuse patch 2.6
  if [ "`patch --version | sed q`" = "patch 2.6" ]; then
    echo "patch 2.6 is incompatible with these scripts."
    echo "Please install either version 2.5.9 (or earlier)"
    echo "or version 2.6.1 (or later.)"
    exit -1
  fi
}

CheckPatchVersion


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


Fetch() {
  Banner "Fetching ${PACKAGE_NAME}"
  if which wget ; then
    wget $1 -O $2
  elif which curl ; then
    curl --location --url $1 -o $2
  else
     Banner "Problem encountered"
     echo "Please install curl or wget and rerun this script"
     echo "or manually download $1 to $2"
     echo
     echo "press any key when done"
     ReadKey
  fi

  if [ ! -s $2 ] ; then
    echo "ERROR: could not find $2"
    exit -1
  fi
}


Check() {
  # verify sha1 checksum for tarball
  local IN_FILE=${NACL_PACKAGES_SCRIPTS}/${PACKAGE_NAME}/${PACKAGE_NAME}.sha1
  if ${SHA1CHECK} <${IN_FILE} &>/dev/null; then
    return 0
  else
    return 1
  fi
}


DefaultDownloadStep() {
  cd ${NACL_PACKAGES_TARBALLS}
  # if matching tarball already exists, don't download again
  if ! Check ; then
    Fetch ${URL} ${PACKAGE_NAME}.tgz
    if ! Check ; then
       Banner "${PACKAGE_NAME} failed checksum!"
       exit -1
    fi
  fi
}


DefaultDownloadBzipStep() {
  cd ${NACL_PACKAGES_TARBALLS}
  # if matching tarball already exists, don't download again
  if ! Check ; then
    Fetch ${URL} ${PACKAGE_NAME}.tbz2
    if ! Check ; then
       Banner "${PACKAGE_NAME} failed checksum!"
       exit -1
    fi
  fi
}


Patch() {
  local LOCAL_PACKAGE_NAME=$1
  local LOCAL_PATCH_FILE=$2
  if [ ${#LOCAL_PATCH_FILE} -ne 0 ]; then
    Banner "Patching ${LOCAL_PACKAGE_NAME}"
    cd ${NACL_PACKAGES_REPOSITORY}
    patch -p0 < ${NACL_PACKAGES_SCRIPTS}/${LOCAL_PATCH_FILE}
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


IsInstalled() {
  local LOCAL_PACKAGE_NAME=$1
  if [ ${#LOCAL_PACKAGE_NAME} -ne 0 ]; then
    if grep -qx ${LOCAL_PACKAGE_NAME} ${NACL_PACKAGES_OUT}/installed.txt \
       &>/dev/null; then
      return 0
    else
      return 1
    fi
  else
    echo "IsInstalled called with possibly unset variable!"
  fi
}


AddToInstallFile() {
  local LOCAL_PACKAGE_NAME=$1
  if ! IsInstalled ${LOCAL_PACKAGE_NAME}; then
    echo ${LOCAL_PACKAGE_NAME} >> ${NACL_PACKAGES_OUT}/installed.txt
  fi
}


PatchSpecFile() {
  # fix up spaces so gcc sees entire path
  local SED_SAFE_SPACES_USR_INCLUDE=${NACL_SDK_MULTIARCH_USR_INCLUDE/ /\ /}
  local SED_SAFE_SPACES_USR_LIB=${NACL_SDK_MULTIARCH_USR_LIB/ /\ /}
  # have nacl-gcc dump specs file & add include & lib search paths
  ${NACLCC} -dumpspecs |\
    awk '/\*cpp:/ {\
      printf("*nacl_arch:\n%%{m64:nacl64; m32:nacl; :nacl64}\n\n", $1); } \
      { print $0; }' |\
    sed "/*cpp:/{
      N
      s|$| -I${SED_SAFE_SPACES_USR_INCLUDE}|
    }" |\
    sed "/*link_libgcc:/{
      N
      s|$| -L${SED_SAFE_SPACES_USR_LIB}|
    }" >${NACL_SDK_GCC_SPECS_PATH}/specs
}


DefaultPreInstallStep() {
  cd ${NACL_TOP}
  MakeDir ${NACL_SDK_USR}
  MakeDir ${NACL_SDK_USR_INCLUDE}
  MakeDir ${NACL_SDK_USR_LIB}
  MakeDir ${NACL_PACKAGES_REPOSITORY}
  MakeDir ${NACL_PACKAGES_TARBALLS}
  MakeDir ${NACL_PACKAGES_PUBLISH}
  Remove ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
}


DefaultExtractStep() {
  Banner "Untaring ${PACKAGE_NAME}.tgz"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  Remove ${PACKAGE_NAME}
  if [ $OS_SUBDIR = "windows" ]; then
    tar --no-same-owner -zxf ${NACL_PACKAGES_TARBALLS}/${PACKAGE_NAME}.tgz
  else
    tar zxf ${NACL_PACKAGES_TARBALLS}/${PACKAGE_NAME}.tgz
  fi
}


DefaultExtractBzipStep() {
  Banner "Untaring ${PACKAGE_NAME}.tbz2"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  Remove ${PACKAGE_NAME}
  if [ $OS_SUBDIR = "windows" ]; then
    tar --no-same-owner -jxf ${NACL_PACKAGES_TARBALLS}/${PACKAGE_NAME}.tbz2
  else
    tar jxf ${NACL_PACKAGES_TARBALLS}/${PACKAGE_NAME}.tbz2
  fi
}


# TODO(khim): remove this when nacl-gcc -V doesn't lockup.
# See: http://code.google.com/p/nativeclient/issues/detail?id=2074
TemporaryVersionWorkaround() {
  if [ $OS_SUBDIR = "windows" ]; then
    Banner "TEMPORARY: Replacing -V with --version for ${PACKAGE_NAME}"
    cd ${NACL_PACKAGES_REPOSITORY}
    # Generic.
    sed -i 's/-V/--version/g' ${PACKAGE_NAME}/configure || true
    # For freetype.
    sed -i 's/-V/--version/g' ${PACKAGE_NAME}/builds/unix/configure || true
    sed -i 's/-V/--version/g' ${PACKAGE_NAME}/builds/unix/aclocal.m4 || true
  fi
}


DefaultPatchStep() {
  Patch ${PACKAGE_NAME} ${PATCH_FILE}
  TemporaryVersionWorkaround
}


DefaultConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACL_SDK_USR_LIB}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACL_SDK_USR_LIB}
  export PATH=${NACL_BIN_PATH}:${PATH};
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  Remove ${PACKAGE_NAME}-build
  MakeDir ${PACKAGE_NAME}-build
  cd ${PACKAGE_NAME}-build
  ../configure \
    --host=nacl \
    --disable-shared \
    --prefix=${NACL_SDK_USR} \
    --exec-prefix=${NACL_SDK_USR} \
    --libdir=${NACL_SDK_USR_LIB} \
    --oldincludedir=${NACL_SDK_USR_INCLUDE} \
    --with-http=off \
    --with-html=off \
    --with-ftp=off \
    --${NACL_OPTION}-mmx \
    --${NACL_OPTION}-sse \
    --${NACL_OPTION}-sse2 \
    --${NACL_OPTION}-asm \
    --with-x=no
}


DefaultBuildStep() {
  # assumes pwd has makefile
  make clean
  make -j${OS_JOBS}
}


DefaultTouchStep() {
  BITSPEC="32"
  if [ "$NACL_BIT_SPEC" = "64" ]; then
    BITSPEC="64"
  fi
  mkdir -p ${NACL_PACKAGES_OUT}/sentinels && \
  touch ${NACL_PACKAGES_OUT}/sentinels/sentinel_file_${BITSPEC}_${PACKAGE_NAME}
}


DefaultInstallStep() {
  # assumes pwd has makefile
  make install
  DefaultTouchStep
}


DefaultCleanUpStep() {
  PatchSpecFile
  AddToInstallFile ${PACKAGE_NAME}
  ChangeDir ${SAVE_PWD}
}


DefaultPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  DefaultConfigureStep
  DefaultBuildStep
  DefaultInstallStep
  DefaultCleanUpStep
}
