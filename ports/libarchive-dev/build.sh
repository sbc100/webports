#!/bin/bash
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# TODO(mtomasz): Remove this package, once a new upstream release of libarchive
# is available.

AutogenStep() {
  ChangeDir ${SRC_DIR}
  export MAKE_LIBARCHIVE_RELEASE="1"
  ./build/autogen.sh
  PatchConfigure
  cd -
}

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  LIBS+=" -lglibc-compat"
  EXTRA_CONFIGURE_ARGS+=" --enable-shared=no"
fi

ConfigureStep() {
  AutogenStep

  EXTRA_CONFIGURE_ARGS="--disable-bsdtar --disable-bsdcpio"
  EXTRA_CONFIGURE_ARGS+=" --without-iconv"

  # Temporary xml2 support cannot be added because the patch used in
  # ports/libarchve doesn't apply correctly here due. The reason is that
  # configure file is not present on gihub repository and is created
  # after AutogenStep.
  # # TODO(cmihail): Remove this once nacl.patch is applied correctly.
  EXTRA_CONFIGURE_ARGS+=" --without-xml2"

  NACLPORTS_CPPFLAGS+=" -Dtimezone=_timezone"

  DefaultConfigureStep
}
