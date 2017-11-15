# Copyright (c) 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

ConfigureStep() {
  EnableGlibcCompat
  EXTRA_CONFIGURE_ARGS+=" --disable-docs"
  NACLPORTS_CFLAGS+=" -std=gnu99"
  EnableCliMain
  DefaultConfigureStep
}
