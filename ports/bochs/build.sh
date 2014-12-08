# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Linux disk image
readonly LINUX_IMG_URL=http://storage.googleapis.com/nativeclient-mirror/nacl/bochs-linux-img.tar.gz
readonly LINUX_IMG_NAME=linux-img

BOCHS_EXAMPLE_DIR=${NACL_SRC}/ports/bochs
EXECUTABLES=bochs

ConfigureStep() {
  SetupCrossEnvironment

  EXTRA_LINK_OPTS="-L${NACLPORTS_LIBDIR}"
  EXTRA_LINK_OPTS+=" -lppapi_simple -lppapi_cpp -ltar -lnacl_io"
  export EXTRA_LINK_OPTS

  EXE=${NACL_EXEEXT} LogExecute ${SRC_DIR}/configure \
    --host=nacl \
    --prefix=${PREFIX} \
    --with-x=no \
    --with-x11=no \
    --with-sdl=yes \
    --with-gnu-ld
}

ImageExtractStep() {
  Banner "Untaring $1 to $2"
  ChangeDir ${WORK_DIR}
  Remove $2
  if [ $OS_SUBDIR = "windows" ]; then
    tar --no-same-owner -zxf ${NACL_PACKAGES_CACHE}/$1
  else
    tar zxf ${NACL_PACKAGES_CACHE}/$1
  fi
}

BuildStep() {
  # boch's Makefile runs sdl-config so we need to cross envrionment setup
  # during build as well as configure.
  SetupCrossEnvironment
  DefaultBuildStep
}

InstallStep() {
  ChangeDir ${SRC_DIR}
  mkdir -p img/usr/local/share/bochs/
  cp -r ${WORK_DIR}/${LINUX_IMG_NAME} img/
  mv img/linux-img/bochsrc old-bochsrc
  cp ${START_DIR}/bochsrc img/linux-img/bochsrc
  cp -r ${SRC_DIR}/bios/VGABIOS-lgpl-latest img/
  cp -r ${SRC_DIR}/bios/BIOS-bochs-latest img/
  cp -r ${SRC_DIR}/msrs.def img/

  MakeDir ${PUBLISH_DIR}

  cd img
  tar cf ${PUBLISH_DIR}/img.tar .
  cd ..

  LogExecute cp ${START_DIR}/bochs.html ${PUBLISH_DIR}
  LogExecute cp ${BUILD_DIR}/bochs ${PUBLISH_DIR}/bochs_${NACL_ARCH}${NACL_EXEEXT}

  if [ ${NACL_ARCH} = pnacl ]; then
    sed -i.bak 's/x-nacl/x-pnacl/g' ${PUBLISH_DIR}/bochs.html
  fi

  pushd ${PUBLISH_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      bochs*${NACL_EXEEXT} \
      -s . \
      -o bochs.nmf
  popd
}

CustomCheck() {
  # verify sha1 checksum for tarball
  if ${SHA1CHECK} <$1 &>/dev/null; then
    return 0
  else
    return 1
  fi
}

ImageDownloadStep() {
  cd ${NACL_PACKAGES_CACHE}
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
  ARCHIVE_NAME=$2.tar.gz
  SHA1=${BOCHS_EXAMPLE_DIR}/$2/$2.sha1
  ImageDownloadStep $1 $2 ${SHA1}
  ImageExtractStep ${ARCHIVE_NAME} $2
  unset ARCHIVE_NAME
}

DownloadStep() {
  FetchLinuxStep ${LINUX_IMG_URL} ${LINUX_IMG_NAME}
}
