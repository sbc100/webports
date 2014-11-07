# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

export EXTRA_LIBS="${NACL_CLI_MAIN_LIB} -lppapi_simple \
  -lnacl_spawn -lnacl_io -lppapi -lppapi_cpp -l${NACL_CPP_LIB}"

EXECUTABLES=tests/devenv_small_test_${NACL_ARCH}${NACL_EXEEXT}

BuildStep() {
  SetupCrossEnvironment

  # Build test module.
  MakeDir ${BUILD_DIR}/tests
  LogExecute ${CXX} ${CPPFLAGS} ${CXXFLAGS} ${LDFLAGS} -g \
      ${START_DIR}/tests/devenv_small_test.cc \
      -o ${BUILD_DIR}/tests/devenv_small_test_${NACL_ARCH}${NACL_EXEEXT} \
      ${EXTRA_LIBS} -lgtest
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}

  local APP_DIR=${PUBLISH_DIR}/app
  MakeDir ${APP_DIR}

  # Set up files for bootstrap.
  local BASH_DIR=${NACL_PACKAGES_PUBLISH}/bash/${TOOLCHAIN}/bash
  local GETURL_DIR=${NACL_PACKAGES_PUBLISH}/geturl/${TOOLCHAIN}
  local UNZIP_DIR=${NACL_PACKAGES_PUBLISH}/unzip/${TOOLCHAIN}

  LogExecute cp -fR ${BASH_DIR}/* ${APP_DIR}

  # On newlib there won't be libs, so turn on null glob for these copies.
  shopt -s nullglob
  LogExecute cp -fR ${GETURL_DIR}/{*.nexe,*.pexe,*.nmf,lib*} ${APP_DIR}
  LogExecute cp -fR ${UNZIP_DIR}/{*.nexe,*.pexe,*.nmf,lib*} ${APP_DIR}
  shopt -u nullglob

  # Install the HTML/JS for the terminal.
  ChangeDir ${APP_DIR}
  LogExecute python ${TOOLS_DIR}/create_term.py -i whitelist.js bash.nmf
  InstallNaClTerm ${APP_DIR}

  RESOURCES="background.js bash.js bashrc setup-environment
      graphical.html whitelist.js devenv_16.png devenv_48.png
      devenv_128.png"
  for resource in ${RESOURCES}; do
    cp ${START_DIR}/${resource} ${APP_DIR}/
  done
  sed "s/[$]{TOOLCHAIN}/${TOOLCHAIN}/g" ${START_DIR}/package \
    > ${APP_DIR}/package

  # Generate a manifest.json.
  GenerateManifest ${START_DIR}/manifest.json.template ${APP_DIR} \
    ${START_DIR}/key.txt

  # Create uploadable version (key not included).
  local APP_UPLOAD_DIR="${PUBLISH_DIR}/devenv_app_upload"
  rm -rf ${APP_UPLOAD_DIR}
  LogExecute cp -r ${APP_DIR} ${APP_UPLOAD_DIR}
  GenerateManifest ${START_DIR}/manifest.json.template ${APP_UPLOAD_DIR}

  # Zip the full app for upload.
  ChangeDir ${PUBLISH_DIR}
  LogExecute zip -r devenv_app_upload.zip devenv_app_upload/

  # Copy the files for DevEnvWidget.
  local WIDGET_DIR=${PUBLISH_DIR}/devenvwidget
  MakeDir ${WIDGET_DIR}
  LogExecute cp -r ${START_DIR}/devenvwidget/* ${WIDGET_DIR}

  # Install tests.
  MakeDir ${PUBLISH_DIR}/tests
  LogExecute cp -r ${BUILD_DIR}/tests/* ${PUBLISH_DIR}/tests
  cd ${PUBLISH_DIR}/tests
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    LogExecute ${PNACLFINALIZE} devenv_small_test_${NACL_ARCH}${NACL_EXEEXT}
  fi
  LogExecute python ${NACL_SDK_ROOT}/tools/create_nmf.py \
      devenv_small_test_${NACL_ARCH}${NACL_EXEEXT} \
      -s . \
      -o devenv_small_test.nmf
  LogExecute mv devenv_small_test_${NACL_ARCH}${NACL_EXEEXT} \
      devenv_small_test_${NACL_ARCH}

  LogExecute zip -r devenv_small_test.zip *
}

PostInstallTestStep() {
  local arches=
  if [[ ${OS_NAME} == Darwin && ${NACL_ARCH} == x86_64 ]]; then
    echo "Skipping devenv tests on unsupported mac + x86_64 configuration."
  elif [[ ${NACL_ARCH} == arm ]]; then
    echo "Skipping devenv tests on arm for now."
  elif [[ ${NACL_ARCH} == pnacl ]]; then
    arches="i686 x86_64"
  else
    arches="${NACL_ARCH}"
  fi
  for arch in ${arches}; do
    LogExecute python ${START_DIR}/devenv_small_test.py -x -vv -a ${arch}
  done
}
