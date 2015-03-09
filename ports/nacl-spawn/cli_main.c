/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

/* Define a typical entry point for command line tools spawned by bash
 * (e.g., ls, objdump, and objdump). */

#include "nacl_io/nacl_io.h"
#include "nacl_main.h"
#include "ppapi_simple/ps.h"
#include "ppapi_simple/ps_main.h"

int cli_main(int argc, char* argv[]) {
  nacl_setup_env();
  return nacl_main(argc, argv);
}

PPAPI_SIMPLE_REGISTER_MAIN(cli_main)
