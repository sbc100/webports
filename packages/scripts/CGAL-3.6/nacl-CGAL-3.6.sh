#!/bin/bash
# Copyright (c) 2010 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that be
# found in the LICENSE file.
#

# nacl-CGAL-3.6.sh
#
# usage:  nacl-CGAL-3.6.sh
#
# this script downloads, patches, and builds CGAL for Native Client
#

readonly URL=http://build.chromium.org/mirror/nacl/CGAL-3.6.tar.gz
#readonly URL=https://gforge.inria.fr/frs/download.php/26688/CGAL-3.6.tar.gz
readonly PATCH_FILE=CGAL-3.6/nacl-CGAL-3.6.patch
readonly PACKAGE_NAME=CGAL-3.6

source ../common.sh

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export LIB_CGAL=libCGAL.a
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
}

CustomInstallStep() {
  Remove ${NACL_SDK_USR_LIB}/${LIB_CGAL}
  install --mode=644 ${LIB_CGAL} ${NACL_SDK_USR_LIB}/${LIB_CGAL}
  Remove ${NACL_SDK_USR_INCLUDE}/CGAL
  ChangeDir include
  tar cf - --exclude='Geomview_stream.h' CGAL | \
    ( ChangeDir ${NACL_SDK_USR_INCLUDE} ; tar xfp - )
}

CustomPackageInstall() {
   DefaultPreInstallStep
   DefaultDownloadStep
   DefaultExtractStep
   DefaultPatchStep
   CustomConfigureStep
   DefaultBuildStep
   CustomInstallStep
   DefaultCleanUpStep
}

CustomPackageInstall
exit 0
