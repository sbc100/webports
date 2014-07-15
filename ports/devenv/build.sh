#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BuildStep() {
  # Nothing to build.
  return
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}

  local APP_DIR=${PUBLISH_DIR}/app
  MakeDir ${APP_DIR}

  # Set up files for bootstrap.
  local BASH_DIR=${NACL_PACKAGES_PUBLISH}/bash/${TOOLCHAIN}/bash
  local CURL_DIR=${NACL_PACKAGES_PUBLISH}/curl/${TOOLCHAIN}
  local UNZIP_DIR=${NACL_PACKAGES_PUBLISH}/unzip/${TOOLCHAIN}

  LogExecute cp -fR ${BASH_DIR}/* ${APP_DIR}
  # We will be providing a devenv background.js.
  rm ${BASH_DIR}/background.js

  # On newlib there won't be libs, so turn on null glob for these copies.
  shopt -s nullglob
  LogExecute cp -fR ${CURL_DIR}/{*.{nexe,nmf},lib*} ${APP_DIR}
  LogExecute cp -fR ${UNZIP_DIR}/{*.{nexe,nmf},lib*} ${APP_DIR}
  shopt -u nullglob

  RESOURCES="background.js bash.js bashrc package setup-environment
      graphical.html"
  for resource in ${RESOURCES}; do
    cp ${START_DIR}/${resource} ${APP_DIR}/
  done

  # Generate a manifest.json.
  GenerateManifest ${START_DIR}/manifest.json.template ${APP_DIR}

  # Zip the full app for upload.
  ChangeDir ${PUBLISH_DIR}
  LogExecute zip -r devenv_app.zip app
}

PostInstallTestStep() {
  if [[ ${OS_NAME} == Darwin && ${NACL_ARCH} == x86_64 ]]; then
    echo "Skipping devenv tests on unsupported mac + x86_64 configuration."
  elif [[ ${NACL_ARCH} == arm ]]; then
    echo "Skipping devenv tests on arm for now."
  else
    LogExecute python ${START_DIR}/devenv_test.py -x -vv -a ${NACL_ARCH}
  fi
}
