# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

EXTRA_CONFIGURE_ARGS+=" --with-x"
EXTRA_CONFIGURE_ARGS+=" --x-includes=${NACLPORTS_INCLUDE}"
EXTRA_CONFIGURE_ARGS+=" --x-libraries=${NACLPORTS_LIBDIR}"
EXTRA_CONFIGURE_ARGS+=" --with-bidi=no"
EXTRA_CONFIGURE_ARGS+=" --with-gnome=no"
EXTRA_CONFIGURE_ARGS+=" --disable-shm"

NACLPORTS_CPPFLAGS+=" -Dmain=nacl_main"

export ac_cv_func_setpgrp_void=no

EXECUTABLES="\
  modules/FvwmIconMan/FvwmIconMan${NACL_EXEEXT} \
  modules/FvwmDragWell/FvwmDragWell${NACL_EXEEXT} \
  modules/FvwmScroll/FvwmScroll${NACL_EXEEXT} \
  modules/FvwmBacker/FvwmBacker${NACL_EXEEXT} \
  modules/FvwmSaveDesk/FvwmSaveDesk${NACL_EXEEXT} \
  modules/FvwmBanner/FvwmBanner${NACL_EXEEXT} \
  modules/FvwmAuto/FvwmAuto${NACL_EXEEXT} \
  modules/FvwmCpp/FvwmCpp${NACL_EXEEXT} \
  modules/FvwmProxy/FvwmProxy${NACL_EXEEXT} \
  modules/FvwmButtons/FvwmButtons${NACL_EXEEXT} \
  modules/FvwmConsole/FvwmConsole${NACL_EXEEXT} \
  modules/FvwmConsole/FvwmConsoleC${NACL_EXEEXT} \
  modules/FvwmSave/FvwmSave${NACL_EXEEXT} \
  modules/FvwmIdent/FvwmIdent${NACL_EXEEXT} \
  modules/FvwmIconBox/FvwmIconBox${NACL_EXEEXT} \
  modules/FvwmForm/FvwmForm${NACL_EXEEXT} \
  modules/FvwmPager/FvwmPager${NACL_EXEEXT} \
  modules/FvwmRearrange/FvwmRearrange${NACL_EXEEXT} \
  modules/FvwmCommand/FvwmCommandS${NACL_EXEEXT} \
  modules/FvwmCommand/FvwmCommand${NACL_EXEEXT} \
  modules/FvwmTaskBar/FvwmTaskBar${NACL_EXEEXT} \
  modules/FvwmWinList/FvwmWinList${NACL_EXEEXT} \
  modules/FvwmScript/FvwmScript${NACL_EXEEXT} \
  modules/FvwmWharf/FvwmWharf${NACL_EXEEXT} \
  modules/FvwmAnimate/FvwmAnimate${NACL_EXEEXT} \
  modules/FvwmEvent/FvwmEvent${NACL_EXEEXT} \
  modules/FvwmTheme/FvwmTheme${NACL_EXEEXT} \
  modules/FvwmM4/FvwmM4${NACL_EXEEXT} \
  fvwm/fvwm${NACL_EXEEXT} \
  bin/fvwm-root${NACL_EXEEXT}"

export LIBS+="\
  -lXext -lXmu -lSM -lICE -lXt -lX11 -lxcb -lXau \
  -Wl,--undefined=nacl_main ${NACL_CLI_MAIN_LIB} \
  -lppapi_simple -lnacl_io -lppapi -lppapi_cpp -lm -l${NACL_CPP_LIB}"

if [ "${NACL_LIBC}" = "newlib" ]; then
  NACLPORTS_CPPFLAGS+=" -I${NACLPORTS_INCLUDE}/glibc-compat"
  export LIBS+=" -lglibc-compat"
fi

if [ "${TOOLCHAIN}" = "pnacl" ]; then
  NACLPORTS_CPPFLAGS+=" -Wno-return-type"
fi

PublishStep() {
  PublishByArchForDevEnv
}
