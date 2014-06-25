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
  # On newlib there won't be libs, so turn on null glob for these copies.
  shopt -s nullglob
  LogExecute cp -fR ${CURL_DIR}/{*.{nexe,nmf},lib*} ${APP_DIR}
  LogExecute cp -fR ${UNZIP_DIR}/{*.{nexe,nmf},lib*} ${APP_DIR}
  shopt -u nullglob

  # Download old version of python.
  local python_url=https://nacltools.storage.googleapis.com/python
  curl ${python_url}/python_store-2.7.5.3/pydata_x86_32.tar \
    -o ${APP_DIR}/pydata_x86_32.tar
  curl ${python_url}/python_store-2.7.5.3/pydata_x86_64.tar \
    -o ${APP_DIR}/pydata_x86_64.tar

  cp ${START_DIR}/bash.js ${APP_DIR}
  cp ${START_DIR}/bashrc ${APP_DIR}
  cp ${START_DIR}/graphical.html ${APP_DIR}

  # Generate a manifest.json.
  GenerateManifest ${START_DIR}/manifest.json.template ${APP_DIR}

  # Zip the full app for upload.
  ChangeDir ${PUBLISH_DIR}
  LogExecute zip -r devenv_app.zip app
}
