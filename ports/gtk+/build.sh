# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

ConfigureStep() {
  if [ "${NACL_LIBC}" = "newlib" ]; then
    # newlib requires different library order to deal with static libraries
    export LIBS+=" -lXext -lX11 -lxcb -lXau"
    NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  fi

  # fix pkgconfig files to explicitly include libffi
  # for things that depend on glib
  sed -i 's/-lglib-2.0 -lintl/-lglib-2.0 -lffi -lintl/'\
   ${NACLPORTS_LIBDIR}/pkgconfig/glib-2.0.pc

  EXTRA_CONFIGURE_ARGS+=" --disable-shm --enable-explicit-deps --disable-cups \
   --enable-gtk-doc-html=no"

  NACLPORTS_CPPFLAGS+=" -Dmain=nacl_main -pthread"
  NACLPORTS_LDFLAGS+=" ${NACL_CLI_MAIN_LIB}"
  export enable_gtk_doc=no

  DefaultConfigureStep
}

PublishStep() {
  MakeDir ${PUBLISH_DIR}
  local APP_DIR="${PUBLISH_DIR}/${NACL_ARCH}/gtk+"
  MakeDir ${APP_DIR}
  ChangeDir ${APP_DIR}
  local exe="${APP_DIR}/gtk-demo${NACL_EXEEXT}"
  LogExecute cp ${INSTALL_DIR}/naclports-dummydir/bin/gtk-demo${NACL_EXEEXT} \
   ${exe}
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
          ${exe} -s . -L ${INSTALL_DIR}/naclports-dummydir/lib \
          -o gtk-demo.nmf
  LogExecute python ${TOOLS_DIR}/create_term.py -n gtk-demo gtk-demo.nmf
  InstallNaClTerm ${APP_DIR}
  LogExecute cp -f ${START_DIR}/*.js ${APP_DIR}
}
