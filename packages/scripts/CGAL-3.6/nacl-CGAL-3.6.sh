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
  export PKG_CONFIG_PATH=${NACL_SDK_USR_LIB}/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACL_SDK_USR_LIB}
  export PATH=${NACL_BIN_PATH}:${PATH};
  export NACL_INCLUDE=${NACL_SDK_USR_INCLUDE}
  export PACKAGE_PATH=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
}

CustomPackageInstall() {
   DefaultPreInstallStep
   DefaultDownloadStep
   DefaultExtractStep
   DefaultPatchStep
   CustomConfigureStep
   DefaultBuildStep
   DefaultInstallStep
   DefaultCleanUpStep
}

CustomPackageInstall
exit 0
