#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-FreeImage-3.14.1.sh
#
# usage:  nacl-FreeImage-3.14.1.sh
#
# This script downloads, patches, and builds FreeImage for Native Client
# See http://freeimage.sourceforge.net/ for more details.
#

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/FreeImage3141.zip
#readonly URL=http://downloads.sourceforge.net/freeimage/FreeImage3141.zip
readonly PATCH_FILE=FreeImage-3.14.1/nacl-FreeImage-3.14.1.patch
readonly PACKAGE_BASE_NAME=FreeImage
readonly PACKAGE_NAME=${PACKAGE_BASE_NAME}-3.14.1
# This list of files needs to have CRLF (Windows)-style line endings translated
# to LF (*nix)-style line endings prior to applying the patch.  This list of
# files is taken from nacl-FreeImage-3.14.1.patch.
readonly -a CRLF_TRANSLATE_FILES=(
    "Makefile"
    "Source/LibOpenJPEG/opj_includes.h"
    "Source/LibRawLite/dcraw/dcraw.c"
    "Source/LibRawLite/internal/defines.h"
    "Source/LibRawLite/libraw/libraw.h"
    "Source/LibRawLite/src/libraw_cxx.cpp"
    "Source/OpenEXR/Imath/ImathMatrix.h"
    "Source/Utilities.h")

source ../../../build_tools/common.sh

CustomPreInstallStep() {
  DefaultPreInstallStep
  Remove ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_BASE_NAME}
}

CustomDownloadStep() {
  cd ${NACL_PACKAGES_TARBALLS}
  # If matching tarball already exists, don't download again
  if ! Check ; then
    Fetch ${URL} ${PACKAGE_NAME}.zip
    if ! Check ; then
       Banner "${PACKAGE_NAME} failed checksum!"
       exit -1
    fi
  fi
}

CustomExtractStep() {
  Banner "Unzipping ${PACKAGE_NAME}"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}
  Remove ${PACKAGE_NAME}
  unzip ${NACL_PACKAGES_TARBALLS}/${PACKAGE_NAME}.zip
  # FreeImage uses CRLF for line-endings.  The patch file has LF (Unix-style)
  # line endings, which means on some versions of patch, the patch fails. Run a
  # recursive tr over all the sources to remedy this.
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_BASE_NAME}
  # Setting LC_CTYPE is a Mac thing.  The locale needs to be set to "C" so that
  # tr interprets the '\r' string as ASCII and not UTF-8.
  export
  for crlf in ${CRLF_TRANSLATE_FILES[@]}; do
    echo "tr -d '\r' < ${crlf}"
    LC_CTYPE=C tr -d '\r' < ${crlf} > .tmp
    mv .tmp ${crlf}
    done
}

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PATH=${NACL_BIN_PATH}:${PATH};
  export INCDIR=${NACL_SDK_USR_INCLUDE}
  export INSTALLDIR=${NACL_SDK_USR_LIB}
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_BASE_NAME}
}

CustomBuildStep() {
  # assumes pwd has makefile
  make OS=nacl clean
  make OS=nacl -j4
}

CustomInstallStep() {
  # assumes pwd has makefile
  make OS=nacl install
  DefaultTouchStep
}

CustomPackageInstall() {
   CustomPreInstallStep
   CustomDownloadStep
   CustomExtractStep
   DefaultPatchStep
   CustomConfigureStep
   CustomBuildStep
   CustomInstallStep
   DefaultCleanUpStep
}

CustomPackageInstall
exit 0
