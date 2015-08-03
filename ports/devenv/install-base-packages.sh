#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# This is for bash on NaCl. Note that you cannot use external commands
# until the installation is completed. Also, you cannot use features
# which nacl_io does not support yet (e.g., pipes and sub-shells).

CheckNaClEnabled() {
  # Skip check on if this isn't newlib.
  if [[ "${TOOLCHAIN}" != newlib ]]; then
    return
  fi
  TMP_CHECK_FILE="/tmp/.enable_nacl_check.nexe"
  # Assume we can reuse the test file if present.
  if [[ ! -e ${TMP_CHECK_FILE} ]]; then
    geturl -q _platform_specific/${NACL_ARCH}/bash.nexe \
      ${TMP_CHECK_FILE} || exit 1
  fi
  ${TMP_CHECK_FILE} -c 'exit 42'
  if [[ $? != 42 ]]; then
    echo "*********************** ERROR ***********************"
    echo
    echo "In order to use the NaCl Dev Environment, you must"
    echo "currently enable 'Native Client' at the url:"
    echo "  chrome://flags"
    echo "You must then restart your browser."
    echo
    echo "Eventually this should not be required."
    echo "Follow this issue: https://crbug.com/477808"
    echo
    echo "*********************** ERROR ***********************"
    // TODO: A more proper way to handle error would be "exit 1" here
    // and keep window open so that error message could be shown.
    while [[ 1 == 1 ]]; do
      read
    done
  fi
}

InstallBasePackages() {
  # Core packages.
  local default_packages="\
    -i coreutils \
    -i bash \
    -i curl \
    -i findutils \
    -i grep \
    -i git \
    -i less \
    -i make \
    -i nano \
    -i python \
    -i grep \
    -i vim"

  local have_gcc=0
  if [[ "${NACL_ARCH}" == "i686" || "${NACL_ARCH}" == "x86_64" ]]; then
    default_packages+=" \
  -i emacs \
  -i mingn.base \
  -i mingn.lib"
    have_gcc=1
  fi

  # Check for updates on some packages.
  package ${default_packages[@]} $@

  if [[ ${have_gcc} == 0 ]]; then
    echo "WARNING: \
emacs and gcc not yet available for your platform (coming soon)."
  fi
}

CheckNaClEnabled
InstallBasePackages $@
