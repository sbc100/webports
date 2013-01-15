#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-bochs-2.4.6.sh
#
# usage:  nacl-bochs-2.4.6.sh
#
# this script downloads, patches, and builds bochs for Native Client.
#

URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/bochs-2.4.6.tar.gz
#readonly URL=http://sourceforge.net/projects/bochs/files/bochs/2.4.6/bochs-2.4.6.tar.gz/download
readonly PATCH_FILE=nacl-bochs-2.4.6.patch
PACKAGE_NAME=bochs-2.4.6


# Linux disk image
readonly LINUX_IMG_URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/bochs-linux-img.tar.gz
readonly LINUX_IMG_NAME=linux-img

source pkg_info
source ../../../build_tools/common.sh

BOCHS_EXAMPLE_DIR=${NACL_SRC}/examples/systems/bochs-2.4.6

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export CXXFLAGS="-O2 -g -I${NACL_SDK_ROOT}/include"
  export LDFLAGS=""
  if [ ${NACL_ARCH} = "pnacl" ] ; then
    export CXXFLAGS="-O3 -g"
    export LDFLAGS="-O0 -static"
  fi
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  # path and package magic to make sure we call the right
  # sdl-config, etc.
  export PKG_CONFIG_PATH=${NACL_SDK_USR_LIB}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACL_SDK_USR_LIB}
  export PATH=${NACL_BIN_PATH}:${PATH};
  export PATH="${NACL_SDK_USR_BIN}:${PATH}"

  export NACLBXLIBS="-lnacl-mounts -lpthread"

  # Hacky way of getting around the bochs configuration tools which don't allow
  # --whole-archive and don't allow for multiple libraries with the same name
  # on the linker line
  PWD=$(pwd)
  # TODO(bradnelson): take this out once the sdk is fixed (and do the line
  # after).
  if [ "$NACL_ARCH" = "x86_64" ]; then
    ChangeDir ${NACL_TOOLCHAIN_ROOT}/x86_64-nacl/lib
  elif [ "$NACL_ARCH" = "i686" ]; then
    ChangeDir ${NACL_TOOLCHAIN_ROOT}/x86_64-nacl/lib32
  elif [ "$NACL_ARCH" = "arm" ]; then
    ChangeDir ${NACL_TOOLCHAIN_ROOT}/arm-nacl/lib
  else
    ChangeDir ${NACL_TOOLCHAIN_ROOT}/sdk/lib
  fi
  cp libppapi_cpp.a libppapi_cpp_COPY.a
  ChangeDir ${PWD}

  export LIBS=
  export LIBS="$LIBS -Wl,--start-group"
  export LIBS="$LIBS -lppapi"
  export LIBS="$LIBS -lppapi_cpp"
  export LIBS="$LIBS -Lbochs_ppapi -lbochs_ppapi"
  export LIBS="$LIBS -lnacl-mounts"
  export LIBS="$LIBS -lpthread"
  export LIBS="$LIBS -lppapi_cpp_COPY"
  # TOOD(robertm): investigate why this is only necessary for pnacl
  if [ ${NACL_ARCH} = "pnacl" ] ; then
    export LIBS="$LIBS -lnosys"
  fi
  export LIBS="$LIBS -Wl,--end-group"

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
    --with-x=no \
    --with-x11=no \
    --with-sdl=yes \
    --with-gnu-ld
}

CustomExtractStep(){
  Banner "Untaring ${PACKAGE_NAME}.tar.gz"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  Remove ${PACKAGE_NAME}
  if [ $OS_SUBDIR = "windows" ]; then
    tar --no-same-owner -zxf ${NACL_PACKAGES_TARBALLS}/${PACKAGE_NAME}.tar.gz
  else
    tar zxf ${NACL_PACKAGES_TARBALLS}/${PACKAGE_NAME}.tar.gz
  fi
}

CustomInstallStep(){
  BOCHS_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  BOCHS_BUILD=${BOCHS_DIR}/${PACKAGE_NAME}-build

  ChangeDir ${BOCHS_DIR}
  mkdir -p img/usr/local/share/bochs/
  cp -r ${NACL_PACKAGES_REPOSITORY}/${LINUX_IMG_NAME} img/
  mv img/linux-img/bochsrc old-bochsrc
  cp ${START_DIR}/bochsrc img/linux-img/bochsrc
  cp -r ${BOCHS_DIR}/bios/VGABIOS-lgpl-latest img/
  cp -r ${BOCHS_DIR}/bios/BIOS-bochs-latest img/
  cp -r ${BOCHS_DIR}/msrs.def img/
  cd img

  PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}

  tar cf ${PUBLISH_DIR}/img.tar ./

  cp ${START_DIR}/bochs.html ${PUBLISH_DIR}
  cp ${START_DIR}/bochs.nmf ${PUBLISH_DIR}
  cp ${BOCHS_BUILD}/bochs ${PUBLISH_DIR}/bochs_${NACL_ARCH}.nexe

  cd ..
}

CustomCheck() {
  # verify sha1 checksum for tarball
  if ${SHA1CHECK} <$1 &>/dev/null; then
    return 0
  else
    return 1
  fi
}

CustomDownloadZipStep() {
  cd ${NACL_PACKAGES_TARBALLS}
  # if matching zip already exists, don't download again
  if ! CustomCheck $3; then
    Fetch $1 $2.zip
    if ! CustomCheck $3 ; then
       Banner "${PACKAGE_NAME} failed checksum!"
       exit -1
    fi
  fi
}

CustomDownloadStep() {
  cd ${NACL_PACKAGES_TARBALLS}
  # if matching tarball already exists, don't download again
  if ! CustomCheck $3; then
    Fetch $1 $2.tbz2
    if ! CustomCheck $3 ; then
       Banner "${PACKAGE_NAME} failed checksum!"
       exit -1
    fi
  fi
}

CustomDownloadStep2() {
  cd ${NACL_PACKAGES_TARBALLS}
  # if matching tarball already exists, don't download again
  if ! CustomCheck $3; then
    Fetch $1 $2.tgz
    if ! CustomCheck $3 ; then
       Banner "${PACKAGE_NAME} failed checksum!"
       exit -1
    fi
  fi
}

GameGetStep() {
  PACKAGE_NAME_TEMP=${PACKAGE_NAME}
  PACKAGE_NAME=$2
  SHA1=${BOCHS_EXAMPLE_DIR}/$2/$2.sha1
  CustomDownloadStep2 $1 $2 ${SHA1}
  DefaultExtractStep
  PACKAGE_NAME=${PACKAGE_NAME_TEMP}
}

CustomPatch() {
  local LOCAL_PACKAGE_NAME=$1
  local LOCAL_PATCH_FILE=$2
  if [ ${#LOCAL_PATCH_FILE} -ne 0 ]; then
    Banner "Patching ${LOCAL_PACKAGE_NAME}"
    cd ${NACL_PACKAGES_REPOSITORY}
    patch -p0 < ${LOCAL_PATCH_FILE}
  fi
}

CustomPatchStep() {
  CustomPatch ${PACKAGE_NAME} ${BOCHS_EXAMPLE_DIR}/nacl-bochs-2.4.6.patch
  TemporaryVersionWorkaround
}

CustomPackageInstall() {
  GameGetStep ${LINUX_IMG_URL} ${LINUX_IMG_NAME}
  DefaultPreInstallStep
  CustomDownloadStep2 ${URL} ${PACKAGE_NAME} \
    ${BOCHS_EXAMPLE_DIR}/bochs-2.4.6.sha1
  DefaultExtractStep
  CustomPatchStep
  CustomConfigureStep
  DefaultBuildStep
  if [ ${NACL_ARCH} = "pnacl" ] ; then
    DefaultTranslateStep ${PACKAGE_NAME} ${PACKAGE_NAME}-build/bochs
  fi
  CustomInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
