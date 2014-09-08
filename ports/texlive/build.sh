# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

SCHEME="small"

NACLPORTS_CFLAGS+=" -I${NACLPORTS_INCLUDE}"
NACLPORTS_CXXFLAGS+=" -I${NACLPORTS_INCLUDE}"

EXTRA_CONFIGURE_ARGS="--disable-native-texlive-build \
                      --enable-cxx-runtime-hack \
                      --disable-ipc \
                      --disable-lcdf-typetools \
                      --disable-luajittex \
                      --disable-mktexmf-default \
                      --disable-mktexpk-default \
                      --disable-mktextfm-default \
                      --disable-mkocp-default \
                      --disable-mktexfmt-default \
                      --disable-dependency-tracking \
                      --disable-linked-scripts \
                      --disable-shared \
                      --disable-largefile \
                      --with-banner-add=/NaCl \
                      --without-x"

export EXTRA_LIBS="${NACL_CLI_MAIN_LIB} -ltar -lppapi_simple -lnacl_spawn \
  -lnacl_io -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  NACLPORTS_CXXFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  export LIBS="-lglibc-compat"
fi

ConfigureStep() {
  # TODO(phosek): we should be able to run reautoconf at this point, but
  # this requires automake > 1.12 which is not currently shipped in Ubuntu 12.04
  #${SRC_DIR}/reautoconf

  local build_host=$(${SRC_DIR}/build-aux/config.guess)
  EXTRA_CONFIGURE_ARGS="${EXTRA_CONFIGURE_ARGS} \
                        --build=${build_host} \
                        BUILDCC=cc \
                        BUILDCXX=c++ \
                        BUILDAR=ar \
                        BUILDRANLIB=ranlib \
                        BUILDLIBS="

  export ac_exeext=${NACL_EXEEXT}
  DefaultConfigureStep
}

BuildStep() {
  export CONFIG_SITE
  DefaultBuildStep
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  local ARCH_DIR=${PUBLISH_DIR}/${NACL_ARCH}

  INSTALL_TARGETS="install-strip texlinks"
  (DefaultInstallStep)

  ChangeDir ${PUBLISH_DIR}
  local INSTALL_TL="install-tl-unx.tar.gz"
  local INSTALL_TL_DIR=${ARCH_DIR}/install-tl
  TryFetch "ftp://tug.org/texlive/tlnet/${INSTALL_TL}" ${INSTALL_TL}
  MakeDir ${INSTALL_TL_DIR}
  tar -xf ${INSTALL_TL} --directory ${INSTALL_TL_DIR} --strip-components=1
  rm -rf ${INSTALL_TL}

  ${TOOLS_DIR}/template_expand.py ${START_DIR}/texlive.profile \
    texdir=${ARCH_DIR} scheme=${SCHEME} > ${INSTALL_TL_DIR}/texlive.profile

  LogExecute ${INSTALL_TL_DIR}/install-tl \
    --profile ${INSTALL_TL_DIR}/texlive.profile
  rm -rf ${INSTALL_TL_DIR}

  if [ "${OS_NAME}" != "Darwin" ]; then
    local tl_executables=$(find ${ARCH_DIR}/usr/share/bin -type f -executable)
  else
    local tl_executables=$(find ${ARCH_DIR}/usr/share/bin -type f -perm +u+x)
  fi

  ChangeDir ${ARCH_DIR}/usr/share
  rm -rf bin
  rm -rf readme-html.dir readme-txt.dir
  rm -rf tlpkg
  rm -rf index.html install-tl install-tl.log release-texlive.txt
  rm -rf LICENSE.CTAN LICENSE.TL README README.usergroups
  find . -name "*.log" -print0 | xargs -0 rm
  for f in $(find . -type l); do
    cp --remove-destination $(readlink -f $f) $f
  done
  cp ${SRC_DIR}/texk/kpathsea/texmf.cnf texmf-dist/web2c/texmf.cnf
  ChangeDir ${ARCH_DIR}
  tar cf texdata_${NACL_ARCH}.tar .
  rm -rf usr

  if [ "${OS_NAME}" != "Darwin" ]; then
    local executables=$(find ${DESTDIR}${PREFIX}/bin -type f -executable)
  else
    local executables=$(find ${DESTDIR}${PREFIX}/bin -type f -perm +u+x)
  fi

  for exe in ${executables}; do
    local name=$(basename ${exe})
    name=${name/%.nexe/}
    name=${name/%.pexe/}
    for tl_exe in ${tl_executables}; do
      if [ "${name}" == "$(basename ${tl_exe})" ]; then
        LogExecute cp $(readlink -f ${exe}) ${ARCH_DIR}/${name}
        if $NACLREADELF -V ${ARCH_DIR}/${name} &>/dev/null; then
          pushd ${ARCH_DIR}
          LogExecute cp ${name} ${name}_${NACL_ARCH}${NACL_EXEEXT}
          LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
            ${name}_${NACL_ARCH}${NACL_EXEEXT} -s . -o ${name}.nmf
          LogExecute rm ${name}_${NACL_ARCH}${NACL_EXEEXT}
          LogExecute rm ${name}.nmf
          popd
        fi
      fi
    done
  done

  ChangeDir ${ARCH_DIR}
  LogExecute rm -f ${ARCH_DIR}.zip
  LogExecute zip -r ${ARCH_DIR}.zip .
}
