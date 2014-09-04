# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BuildStep() {
  return
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  ChangeDir ${PUBLISH_DIR}

  LogExecute rm -rf fonts
  LogExecute cp -fR ${NACL_PREFIX}/share/fonts ${PUBLISH_DIR}

  LogExecute zip -r fonts.zip fonts
  LogExecute rm -rf fonts
}
