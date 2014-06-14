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
  local BASH_DIR=${NACL_PACKAGES_PUBLISH}/bash*/${NACL_LIBC}/bash
  local CURL_DIR=${NACL_PACKAGES_PUBLISH}/curl*/${NACL_LIBC}
  local UNZIP_DIR=${NACL_PACKAGES_PUBLISH}/unzip*/${NACL_LIBC}

  LogExecute cp -fR ${BASH_DIR}/* ${APP_DIR}
  LogExecute cp -fR ${CURL_DIR}/{*.{nexe,nmf},lib*} ${APP_DIR}
  LogExecute cp -fR ${UNZIP_DIR}/{*.{nexe,nmf},lib*} ${APP_DIR}

  # Copy bash.js and bashrc.
  cp ${START_DIR}/bash.js ${APP_DIR}
  cp ${START_DIR}/bashrc ${APP_DIR}

  # Generate a manifest.json.
  GenerateManifest ${START_DIR}/manifest.json.template ${APP_DIR}
}
