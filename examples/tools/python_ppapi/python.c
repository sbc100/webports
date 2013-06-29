/* Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

#include "Python.h"
#include <stdio.h>
#include "ppapi_simple/ps_main.h"

int python_main(int argc, char **argv) {
  /* Ignore standard args passed via ppapi_simple */
  int new_argc = 0;
  char* new_argv[argc];
  int i;
  for (i = 0; i < argc; i++) {
    /* Ignore all args that start with -- other then --help and --version.
     * These are the only two long arguments that python takes.  We assume
     * the aothers come from the html embed tag attributed.
     */
    if (!strncmp(argv[i], "--", 2)) {
      if (strcmp(argv[i], "--help") && strcmp(argv[i], "--version"))
        continue;
    }
    new_argv[new_argc++] = argv[i];
  }

  return Py_Main(new_argc, new_argv);
}

PPAPI_SIMPLE_REGISTER_MAIN(python_main)
