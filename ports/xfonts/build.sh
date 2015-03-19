# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BuildStep() {
  return
}

InstallStep() {
  MakeDir ${PUBLISH_DIR}
  ChangeDir ${PUBLISH_DIR}

  LogExecute rm -rf share
  MakeDir share/fonts
  LogExecute cp -fR ${NACL_PREFIX}/share/fonts ${PUBLISH_DIR}/share/
  for dir in $(find ${PUBLISH_DIR}/share/fonts/X11 -type d); do
    LogExecute mkfontscale "$dir"
    LogExecute mkfontdir "$dir"
  done

  LogExecute tar cf xorg-fonts.tar share/
  LogExecute rm -rf share
}
