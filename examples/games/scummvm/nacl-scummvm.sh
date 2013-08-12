#!/bin/bash
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source pkg_info
source ../../../build_tools/common.sh

# Beneath a Steel Sky (floppy version)
readonly BASS_FLOPPY_URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/scummvm_games/bass/BASS-Floppy-1.3.zip
readonly BASS_FLOPPY_NAME=BASS-Floppy-1.3

readonly LURE_URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/scummvm_games/lure/lure-1.1.zip
readonly LURE_NAME=lure-1.1

SCUMMVM_EXAMPLE_DIR=${NACL_SRC}/examples/games/scummvm

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  # without this setting *make* will not show the full command lines
  export VERBOSE_BUILD=1
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_LIBDIR}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_LIBDIR}
  export PATH="${NACL_BIN_PATH}:${PATH}"
  export PATH="${NACLPORTS_PREFIX_BIN}:${PATH}"
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
  export LIBS="$LIBS -lvorbisfile -lvorbis -logg"
  export LIBS="$LIBS -lnacl-mounts"
  export LIBS="$LIBS -lppapi -lppapi_cpp -lppapi_cpp_private"
  export LIBS="$LIBS -Wl,--no-whole-archive"
  export CPPFLAGS="-I$NACL_PACKAGES_LIBRARIES"

  MakeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}/${NACL_BUILD_SUBDIR}
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}/${NACL_BUILD_SUBDIR}
  # NOTE: disabled mt32emu because it using inline assembly that won't
  #     validate.
  ../configure \
    --host=nacl \
    --libdir=${NACLPORTS_LIBDIR} \
    --disable-flac \
    --disable-zlib \
    --disable-mt32emu \
    --disable-all-engines \
    --enable-lure \
    --enable-sky
}

CustomInstallStep() {
  SRC_DIR=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  SCUMMVM_DIR=runimage/usr/local/share/scummvm
  ChangeDir ${SRC_DIR}

  mkdir -p ${SCUMMVM_DIR}
  cp gui/themes/scummclassic.zip \
     dists/engine-data/sky.cpt \
     gui/themes/scummmodern.zip \
     gui/themes/translations.dat \
     dists/engine-data/lure.dat \
     dists/pred.dic \
     ${SCUMMVM_DIR}

  cp `find gui/themes/fonts/ -type f` ${SCUMMVM_DIR}

  Banner "Creating tarballs"
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
  Banner "Publishing to ${PUBLISH_DIR}"
  MakeDir ${PUBLISH_DIR}

  # Prepare AppEngine app.
  APPENGINE_DIR=${PUBLISH_DIR}/appengine
  MakeDir ${APPENGINE_DIR}
  cp `find ${START_DIR}/nacl-scumm -type f -maxdepth 1` ${APPENGINE_DIR}
  MakeDir ${APPENGINE_DIR}/static
  cp ${START_DIR}/nacl-scumm/static/* ${APPENGINE_DIR}/static
  cp ${SRC_DIR}/*.tar ${APPENGINE_DIR}/static
  ${NACLSTRIP} ${SRC_DIR}/${NACL_BUILD_SUBDIR}/scummvm \
      -o ${APPENGINE_DIR}/static/scummvm_${NACL_ARCH}.nexe

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

ExtractGameZipStep() {
  Banner "Unzipping ${PACKAGE_NAME}.zip"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  Remove ${PACKAGE_DIR}
  unzip -d ${PACKAGE_DIR} ${NACL_PACKAGES_TARBALLS}/${PACKAGE_NAME}.zip
}

GameGetStep() {
  PACKAGE_NAME_TEMP=${PACKAGE_NAME}
  PACKAGE_DIR_TEMP=${PACKAGE_DIR}
  PACKAGE_NAME=$2
  PACKAGE_DIR=$2
  SHA1=${SCUMMVM_EXAMPLE_DIR}/$2/$2.sha1
  CustomDownloadZipStep $1 $2 ${SHA1}
  ExtractGameZipStep
  PACKAGE_NAME=${PACKAGE_NAME_TEMP}
  PACKAGE_DIR=${PACKAGE_DIR_TEMP}
}

CustomPackageInstall() {
  GameGetStep ${BASS_FLOPPY_URL} ${BASS_FLOPPY_NAME}
  GameGetStep ${LURE_URL} ${LURE_NAME}
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  CustomInstallStep
}

CustomPackageInstall
exit 0
