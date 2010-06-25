#!/bin/bash
# Copyright (c) 2010 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that be
# found in the LICENSE file.
#

# patch-OpenSceneGraph-2.9.7.sh
#
# usage:  patch-OpenSceneGraph-2.9.7.sh
#
# This script downloads and patches OpenSceneGraph for Native Client.  Note
# that it does not build OpenSceneGraph.
#

readonly URL=http://build.chromium.org/mirror/nacl/OpenSceneGraph-2.9.7.zip
#readonly URL=http://www.openscenegraph.org/downloads/developer_releases/OpenSceneGraph-2.9.7.zip
readonly PATCH_FILE=OpenSceneGraph-2.9.7/nacl-OpenSceneGraph-2.9.7.patch
readonly PACKAGE_NAME=OpenSceneGraph-2.9.7

source ../common.sh


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
  echo ${NACL_SDK_USR_INCLUDE}
  echo ${NACLCXX}
  install --mode=644 ${LIB_OSG} ${NACL_SDK_USR_LIB}/${LIB_OSG}
  install --mode=644 ${LIB_OSGUTIL} ${NACL_SDK_USR_LIB}/${LIB_OSGUTIL}
  install --mode=644 ${LIB_OPENTHREADS} ${NACL_SDK_USR_LIB}/${LIB_OPENTHREADS}
}

CustomPackagePatch() {
   DefaultPreInstallStep
   CustomDownloadStep
   CustomExtractStep
   DefaultPatchStep
   CustomConfigureStep
}

CustomPackagePatch
