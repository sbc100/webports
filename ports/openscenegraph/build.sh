#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_DIR=${SRC_DIR}

export LIB_OSG=libosg.a
export LIB_OSGUTIL=libosgUtil.a
export LIB_OPENTHREADS=libOpenThreads.a

ConfigureStep() {
  return 0
}

BuildStep() {
  SetupCrossEnvironment
  CFLAGS+=" ${CPPFLAGS}"
  CXXFLAGS+=" ${CPPFLAGS}"
  DefaultBuildStep
}

InstallStep() {
  Remove ${NACLPORTS_INCLUDE}/osg
  Remove ${NACLPORTS_INCLUDE}/osgUtil
  Remove ${NACLPORTS_INCLUDE}/OpenThreads
  cp -R include/osg ${NACLPORTS_INCLUDE}/osg
  cp -R include/osgUtil ${NACLPORTS_INCLUDE}/osgUtil
  cp -R include/OpenThreads ${NACLPORTS_INCLUDE}/OpenThreads
  Remove ${NACLPORTS_LIBDIR}/libosg.a
  Remove ${NACLPORTS_LIBDIR}/libosgUtil.a
  Remove ${NACLPORTS_LIBDIR}/libOpenThreads.a
  install -m 644 ${LIB_OSG} ${NACLPORTS_LIBDIR}/${LIB_OSG}
  install -m 644 ${LIB_OSGUTIL} ${NACLPORTS_LIBDIR}/${LIB_OSGUTIL}
  install -m 644 ${LIB_OPENTHREADS} ${NACLPORTS_LIBDIR}/${LIB_OPENTHREADS}
}
