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

readonly URL=http://commondatastorage.googleapis.com/nativeclient-mirror/nacl/OpenSceneGraph-2.9.7.zip
#readonly URL=http://www.openscenegraph.org/downloads/developer_releases/OpenSceneGraph-2.9.7.zip
readonly PATCH_FILE=nacl-OpenSceneGraph-2.9.7.patch
readonly PACKAGE_NAME=OpenSceneGraph-2.9.7

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
  Remove ${NACL_SDK_USR_INCLUDE}/osg
  Remove ${NACL_SDK_USR_INCLUDE}/osgUtil
  Remove ${NACL_SDK_USR_INCLUDE}/OpenThreads
  readonly THIS_PACKAGE_PATH=${NACL_PACKAGES_REPOSITORY}/${PACKAGE_NAME}
  cp -R include/osg ${NACL_SDK_USR_INCLUDE}/osg
  cp -R include/osgUtil ${NACL_SDK_USR_INCLUDE}/osgUtil
  cp -R include/OpenThreads ${NACL_SDK_USR_INCLUDE}/OpenThreads
  Remove ${NACL_SDK_USR_LIB}/libosg.a
  Remove ${NACL_SDK_USR_LIB}/libosgUtil.a
  Remove ${NACL_SDK_USR_LIB}/libOpenThreads.a
  install -m 644 ${LIB_OSG} ${NACL_SDK_USR_LIB}/${LIB_OSG}
  install -m 644 ${LIB_OSGUTIL} ${NACL_SDK_USR_LIB}/${LIB_OSGUTIL}
  install -m 644 ${LIB_OPENTHREADS} ${NACL_SDK_USR_LIB}/${LIB_OPENTHREADS}
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
