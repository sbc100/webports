#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../../build_tools/common.sh

# Linux disk image
readonly LINUX_IMG_URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/bochs-linux-img.tar.gz
readonly LINUX_IMG_NAME=linux-img

BOCHS_EXAMPLE_DIR=${NACL_SRC}/examples/systems/bochs
EXECUTABLES=bochs

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export CXXFLAGS="-O2 -g ${NACLPORTS_CFLAGS}"
  if [ ${NACL_ARCH} = "pnacl" ] ; then
    export CXXFLAGS="-O3 -g ${NACLPORTS_CFLAGS}"
    export LDFLAGS="-O0 -static ${NACLPORTS_LDFLAGS}"
  fi
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  # path and package magic to make sure we call the right
  # sdl-config, etc.
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export PATH=${NACL_BIN_PATH}:${PATH};
  export PATH="${NACLPORTS_PREFIX_BIN}:${PATH}"

  export NACLBXLIBS="-lnacl-mounts -lpthread"

  # Hacky way of getting around the bochs configuration tools which don't allow
  # --whole-archive and don't allow for multiple libraries with the same name
  # on the linker line
  PWD=$(pwd)
  # TODO(bradnelson): take this out once the sdk is fixed (and do the line
  # after).
  ChangeDir ${NACL_SDK_LIBDIR}
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
  Remove ${NACL_BUILD_SUBDIR}
  MakeDir ${NACL_BUILD_SUBDIR}
  cd ${NACL_BUILD_SUBDIR}
  ../configure \
    --host=nacl \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_LIBDIR} \
    --oldincludedir=${NACLPORTS_INCLUDE} \
    --with-x=no \
    --with-x11=no \
    --with-sdl=yes \
    --with-gnu-ld
}

CustomExtractStep() {
  Banner "Untaring $1"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  Remove ${PACKAGE_NAME}
  if [ $OS_SUBDIR = "windows" ]; then
    tar --no-same-owner -zxf ${NACL_PACKAGES_TARBALLS}/$1
  else
    tar zxf ${NACL_PACKAGES_TARBALLS}/$1
  fi
}

CustomInstallStep() {
  BOCHS_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  BOCHS_BUILD=${BOCHS_DIR}/${NACL_BUILD_SUBDIR}

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

CustomDownloadStep() {
  cd ${NACL_PACKAGES_TARBALLS}
  # if matching tarball already exists, don't download again
  if ! CustomCheck $3; then
    Fetch $1 $2.tar.gz
    if ! CustomCheck $3 ; then
       Banner "${PACKAGE_NAME} failed checksum!"
       exit -1
    fi
  fi
}

FetchLinuxStep() {
  Banner "FetchLinuxStep"
  PACKAGE_DIR_TEMP=${PACKAGE_DIR}
  ARCHIVE_NAME=$2.tar.gz
  PACKAGE_DIR=$2
  SHA1=${BOCHS_EXAMPLE_DIR}/$2/$2.sha1
  CustomDownloadStep $1 $2 ${SHA1}
  CustomExtractStep ${ARCHIVE_NAME}
  unset ARCHIVE_NAME
  PACKAGE_DIR=${PACKAGE_DIR_TEMP}
}


CustomPackageInstall() {
  FetchLinuxStep ${LINUX_IMG_URL} ${LINUX_IMG_NAME}
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  DefaultTranslateStep
  DefaultValidateStep
  CustomInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
