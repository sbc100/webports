# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
fi

export LIBS+=" -l${NACL_CPP_LIB}"

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  MakeDir ${PUBLISH_DIR}/${NACL_ARCH}
  # -executable is not supported on BSD and -perm +nn is not
  # supported on linux
  if [ ${OS_NAME} != "Darwin" ]; then
    local EXECUTABLES=$(find src -type f -executable)
  else
    local EXECUTABLES=$(find src -type f -perm +u+x)
  fi
  for nexe in ${EXECUTABLES}; do
    local name=$(basename $nexe)
    # Remove .nexe / .pexe
    name=${name%.*}
    LogExecute cp ${nexe} ${PUBLISH_DIR}/${NACL_ARCH}/${name}
  done
  ChangeDir ${PUBLISH_DIR}/${NACL_ARCH}
  LogExecute rm -f ${PUBLISH_DIR}/${NACL_ARCH}.zip
  LogExecute zip -r ${PUBLISH_DIR}/${NACL_ARCH}.zip .
}
