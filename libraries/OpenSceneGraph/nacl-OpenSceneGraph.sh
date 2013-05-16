#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

# nacl-OpenSceneGraph-2.9.7.sh
#
# usage:  nacl-OpenSceneGraph-2.9.7.sh
#
# this script downloads, patches, and builds OpenSceneGraph for Native Client
#

source pkg_info
source ../../build_tools/common.sh

CustomDownloadStep() {
  cd ${NACL_PACKAGES_TARBALLS}
  # if matching tarball already exists, don't download again
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
}

CustomConfigureStep() {
  Banner "Configuring ${PACKAGE_NAME}"
  # export the nacl tools
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export PATH=${NACL_BIN_PATH}:${PATH};
  export LIB_OSG=libosg.a
  export LIB_OSGUTIL=libosgUtil.a
  export LIB_OPENTHREADS=libOpenThreads.a

  ChangeDir ${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
}

CustomInstallStep() {
  Remove ${NACLPORTS_INCLUDE}/osg
  Remove ${NACLPORTS_INCLUDE}/osgUtil
  Remove ${NACLPORTS_INCLUDE}/OpenThreads
  readonly THIS_PACKAGE_PATH=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  cp -R include/osg ${NACLPORTS_INCLUDE}/osg
  cp -R include/osgUtil ${NACLPORTS_INCLUDE}/osgUtil
  cp -R include/OpenThreads ${NACLPORTS_INCLUDE}/OpenThreads
  Remove ${NACLPORTS_LIBDIR}/libosg.a
  Remove ${NACLPORTS_LIBDIR}/libosgUtil.a
  Remove ${NACLPORTS_LIBDIR}/libOpenThreads.a
  install -m 644 ${LIB_OSG} ${NACLPORTS_LIBDIR}/${LIB_OSG}
  install -m 644 ${LIB_OSGUTIL} ${NACLPORTS_LIBDIR}/${LIB_OSGUTIL}
  install -m 644 ${LIB_OPENTHREADS} ${NACLPORTS_LIBDIR}/${LIB_OPENTHREADS}
  DefaultTouchStep
}

CustomPackageInstall() {
  DefaultPreInstallStep
  CustomDownloadStep
  CustomExtractStep
  DefaultPatchStep
  CustomConfigureStep
  DefaultBuildStep
  CustomInstallStep
  DefaultCleanUpStep
}

CustomPackageInstall
exit 0
