#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-scummvm-1.2.1.sh
#
# usage:  nacl-scummvm-1.2.1.sh
#
# this script downloads, patches, and builds scummvm for Native Client.
#

URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/scummvm-1.2.1.tar.bz2
#readonly URL=http://prdownloads.sourceforge.net/scummvm/scummvm-1.2.1.tar.bz2?download
readonly PATCH_FILE=nacl-scummvm-1.2.1.patch
PACKAGE_NAME=scummvm-1.2.1

# Beneath a Steel Sky (floppy version)
readonly BASS_FLOPPY_URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/scummvm_games/bass/BASS-Floppy-1.3.zip
readonly BASS_FLOPPY_NAME=BASS-Floppy-1.3

readonly LURE_URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/scummvm_games/lure/lure-1.1.zip
readonly LURE_NAME=lure-1.1

source ../../../build_tools/common.sh

SCUMMVM_EXAMPLE_DIR=${NACL_SRC}/examples/games/scummvm-1.2.1

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACL_SDK_USR_LIB}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACL_SDK_USR_LIB}
  export PATH=${NACL_BIN_PATH}:${PATH}
  export PATH="$NACL_TOOLCHAIN_ROOT/i686-nacl/usr/bin:$PATH"
  export PATH="$NACL_TOOLCHAIN_ROOT/x86_64-nacl/usr/bin:$PATH"
  export DEFINES=
  if [ "${NACL_GLIBC}" != "1" ]; then
    export DEFINES="-Dstrdup\(a\)=strcpy\(\(char\*\)malloc\(strlen\(a\)+1\),a\)"
    export DEFINES="$DEFINES -Dvsnprintf\(a,b,c,d\)=vsprintf\(a,c,d\)"
    export DEFINES="$DEFINES -Dsnprintf\(a,b,c,...\)=sprintf\(a,c,__VA_ARGS__\)"
    export DEFINES="$DEFINES -Dstrcasecmp=strcmp"
    export DEFINES="$DEFINES -Dstrncasecmp=strncmp"
  fi
  export DEFINES="$DEFINES -DNACL -DSYSTEM_NOT_SUPPORTING_D_TYPE=1"
  export LIBS=
  export LIBS="$LIBS -Wl,--whole-archive"
  export LIBS="$LIBS -lppapi"
  export LIBS="$LIBS -lppapi_cpp"
  export LIBS="$LIBS -lvorbisfile -lvorbis -logg"
  export LIBS="$LIBS -lnacl-mounts"
  export LIBS="$LIBS -Wl,--no-whole-archive"
  export LDFLAGS=

  # linker wrappers
  if [ "${NACL_GLIBC}" = "1" ]; then
    echo "No linker wrapping for glibc"
  else
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker creat"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker open"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker close"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker read"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker write"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker lseek"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker mkdir"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker rmdir"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker remove"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker getcwd"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker getwd"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker chdir"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker isatty"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker stat"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker fstat"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker access"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker chmod"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker ioctl"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker link"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker getdents"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker kill"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker mount"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker fflush"
    export LDFLAGS="$LDFLAGS -Xlinker --wrap -Xlinker signal"
  fi

  export CPPFLAGS="-I$NACL_PACKAGES_LIBRARIES"

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  Remove ${PACKAGE_NAME}-build
  MakeDir ${PACKAGE_NAME}-build
  # NOTE: disabled mt32emu because it using inline assembly that won't
  #     validate.
  cd ${PACKAGE_NAME}-build
  ../configure \
    --host=nacl \
    --libdir=${NACL_SDK_USR_LIB} \
    --disable-flac \
    --disable-zlib \
    --disable-mt32emu \
    --disable-all-engines \
    --enable-lure \
    --enable-sky
}

CustomInstallStep() {
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  SCUMMVM_DIR=runimage/usr/local/share/scummvm

  mkdir -p ${SCUMMVM_DIR}
  SRC_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  cp ${SRC_DIR}/gui/themes/scummclassic.zip \
     ${SRC_DIR}/dists/engine-data/sky.cpt \
     ${SRC_DIR}/gui/themes/scummmodern.zip \
     ${SRC_DIR}/gui/themes/translations.dat \
     ${SRC_DIR}/dists/engine-data/lure.dat \
     ${SRC_DIR}/dists/pred.dic \
     ${SCUMMVM_DIR}

  cp `find ${SRC_DIR}/gui/themes/fonts/ -type f` ${SCUMMVM_DIR}

  cd runimage
  tar cf ../runimage.tar ./
  cd ..

  #Beneath a Steel Sky (Floppy version)
  BASS_DIR=bass/usr/local/share/scummvm/${BASS_FLOPPY_NAME}
  mkdir -p ${BASS_DIR}
  cp -r ${NACL_PACKAGES_REPOSITORY}/${BASS_FLOPPY_NAME}/* ${BASS_DIR}
  cd bass
  tar cf ../bass.tar ./
  cd ..

  #Lure of the temptress
  LURE_DIR=lure/usr/local/share/scummvm
  mkdir -p ${LURE_DIR}
  cp -r ${NACL_PACKAGES_REPOSITORY}/${LURE_NAME}/* ${LURE_DIR}
  cd lure
  tar cf ../lure.tar ./
  cd ..

  export PUBLISH_DIR="${NACL_PACKAGES_PUBLISH}/${PACKAGE_NAME}"
  MakeDir ${PUBLISH_DIR}

  # Prepare AppEngine app.
  APPENGINE_DIR=${PUBLISH_DIR}/appengine
  MakeDir ${APPENGINE_DIR}
  cp `find ${START_DIR}/nacl-scumm -type f -maxdepth 1` ${APPENGINE_DIR}
  MakeDir ${APPENGINE_DIR}/static
  cp ${START_DIR}/nacl-scumm/static/* ${APPENGINE_DIR}/static
  cp ${SRC_DIR}/*.tar ${APPENGINE_DIR}/static
  ${NACLSTRIP} ${SRC_DIR}/${PACKAGE_NAME}-build/scummvm \
      -o ${APPENGINE_DIR}/static/scummvm_x86_${NACL_PACKAGES_BITSIZE}.nexe

  # Publish chrome web store app (copy to repository to drop .svn etc).
  MakeDir ${SRC_DIR}/hosted_app
  cp ${START_DIR}/hosted_app/* ${SRC_DIR}/hosted_app
  ChangeDir ${SRC_DIR}
  WEBSTORE_DIR=${PUBLISH_DIR}/web_store
  MakeDir ${WEBSTORE_DIR}
  zip -r ${WEBSTORE_DIR}/scummvm-1.2.1.zip hosted_app
  cp ${START_DIR}/screenshots/* ${WEBSTORE_DIR}
  cp ${START_DIR}/hosted_app/scummvm_128.png ${WEBSTORE_DIR}
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

GameGetStep() {
  PACKAGE_NAME_TEMP=${PACKAGE_NAME}
  PACKAGE_NAME=$2
  SHA1=${SCUMMVM_EXAMPLE_DIR}/$2/$2.sha1
  CustomDownloadZipStep $1 $2 ${SHA1}
  DefaultExtractZipStep
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
  CustomPatch ${PACKAGE_NAME} ${SCUMMVM_EXAMPLE_DIR}/nacl-scummvm-1.2.1.patch
  TemporaryVersionWorkaround
}

CustomPackageInstall() {
  GameGetStep ${BASS_FLOPPY_URL} ${BASS_FLOPPY_NAME}
  GameGetStep ${LURE_URL} ${LURE_NAME}
  DefaultPreInstallStep
  CustomDownloadStep ${URL} ${PACKAGE_NAME} \
    ${SCUMMVM_EXAMPLE_DIR}/scummvm-1.2.1.sha1
  DefaultExtractBzipStep
  CustomPatchStep
  CustomConfigureStep
  DefaultBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
