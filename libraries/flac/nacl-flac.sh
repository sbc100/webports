#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-flac-1.2.1.sh
#
# usage:  nacl-flac-1.2.1.sh
#
# this script downloads, patches, and builds flac for Native Client 
#

source pkg_info
source ../../build_tools/common.sh


CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PKG_CONFIG_PATH=${NACLPORTS_PREFIX}/lib/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACLPORTS_PREFIX}/lib
  export PATH=${NACL_BIN_PATH}:${PATH};
  export LIBS="-lnosys"
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  MakeDir ${NACL_BUILD_SUBDIR}
  ChangeDir ${NACL_BUILD_SUBDIR}
  ../configure \
    --host=nacl \
    --prefix=${NACLPORTS_PREFIX} \
    --exec-prefix=${NACLPORTS_PREFIX} \
    --libdir=${NACLPORTS_PREFIX}/lib \
    --oldincludedir=${NACLPORTS_PREFIX}/include \
    --enable-sse \
    --disable-3dnow \
    --disable-altivec \
    --disable-thorough-tests \
    --disable-oggtest \
    --disable-xmms-plugin \
    --without-metaflac-test-files \
    --disable-asm-optimizations \
    --with-http=off \
    --with-html=off \
    --with-ftp=off \
    --with-x=no
}


CustomPostConfigureStep() {
  # add stub includes
  mkdir netinet
  touch netinet/in.h
  # add ntohl for Native Client
  echo "#define ntohl(x) ((((x)>>24)&0xFF)|(((x)>>8)&0xFF00)|\
(((x)<<8)&0xFF0000)|(((x)<<24)&0xFF000000))" >> config.h
  # satisfy random, srandom
  echo "/* pull features.h that has __GLIBC__ */" >> config.h
  echo "#include <stdlib.h>" >> config.h
  echo "#ifndef __GLIBC__" >> config.h
  echo "# define random() rand()" >> config.h
  echo "# define srandom(x) srand(x)" >> config.h
  echo "#endif" >> config.h
}


CustomInstallStep() {
  # assumes pwd has makefile
  make install-exec
  (cd include; make install)
}


CustomPackageInstall() {
  DefaultPreInstallStep
  DefaultDownloadStep
  DefaultExtractStep
  DefaultPatchStep
  CustomConfigureStep
  CustomPostConfigureStep
  DefaultBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}


CustomPackageInstall
exit 0

