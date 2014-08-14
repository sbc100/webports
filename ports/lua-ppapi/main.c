/* Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

#include <unistd.h>

#include "nacl_main.h"
#include "ppapi_simple/ps_main.h"

extern int lua_main(int argc, char **argv);

int nacl_main(int argc, char **argv) {
  if (nacl_startup_untar(argv[0], "luadata.tar", "/"))
    return 1;

  chdir("/lua-5.2.2-tests");

  return lua_main(argc, argv);
}
