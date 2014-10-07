# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}

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



ExtractStep() {
  DefaultExtractStep
  # FreeImage uses CRLF for line-endings.  The patch file has LF (Unix-style)
  # line endings, which means on some versions of patch, the patch fails. Run a
  # recursive tr over all the sources to remedy this.
  # Setting LC_CTYPE is a Mac thing.  The locale needs to be set to "C" so that
  # tr interprets the '\r' string as ASCII and not UTF-8.
  ChangeDir ${SRC_DIR}
  export
  for crlf in "${CRLF_TRANSLATE_FILES[@]}"; do
    echo "Converting line endings: ${crlf}"
    LC_CTYPE=C tr -d '\r' < ${crlf} > .tmp
    mv .tmp ${crlf}
  done
}


ConfigureStep() {
  return
}


BuildStep() {
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PATH=${NACL_BIN_PATH}:${PATH}

  # assumes pwd has makefile
  LogExecute make OS=nacl clean
  LogExecute make OS=nacl -j${OS_JOBS}
}


InstallStep() {
  export INCDIR=${DESTDIR_INCLUDE}
  export INSTALLDIR=${DESTDIR_LIB}
  LogExecute make OS=nacl install
}
