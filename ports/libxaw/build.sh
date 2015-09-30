# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EnableGlibcCompat

InstallStep() {
  if [[ $TOOLCHAIN == newlib ]]; then
     INSTALL_TARGETS="install LIBEXT=.a"
  fi
  DefaultInstallStep
}
