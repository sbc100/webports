# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

ConfigureStep() {
  MakeDir ${BUILD_DIR}
  cp -rf ${START_DIR}/* ${BUILD_DIR}
}

BuildStep() {
  MAKEFLAGS+=" NACL_ARCH=${NACL_ARCH_ALT}"
  export CFLAGS="${NACLPORTS_CPPFLAGS} ${NACLPORTS_CFLAGS}"
  export CXXFLAGS="${NACLPORTS_CPPFLAGS} ${NACLPORTS_CXXFLAGS}"
  export LDFLAGS="${NACLPORTS_LDFLAGS}"
  DefaultBuildStep
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  local name=geturl_${NACL_ARCH_ALT}${NACL_EXEEXT}
  local exe=${PUBLISH_DIR}/${name}
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    LogExecute ${PNACLFINALIZE} ${name} -o ${exe}
  else
    LogExecute cp ${name} ${exe}
  fi
  pushd ${PUBLISH_DIR}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      ${PUBLISH_DIR}/geturl*${NACL_EXEEXT} \
      -L${DESTDIR_LIB} \
      -s . \
      -o geturl.nmf
  popd
}
