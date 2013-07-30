/* Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

#include <assert.h>
#include <libtar.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>

#include "nacl_io/nacl_io.h"
#include "ppapi_simple/ps_main.h"


int lua_main(int argc, char **argv);

int lua_ppapi_main(int argc, char **argv) {
  umount("/");
  mount("foo", "/", "memfs", 0, NULL);
  mount("./", "/mnt/tars", "httpfs", 0, NULL);

  mkdir("/myhome", 0777);

  /* Setup home directory to a known location. */
  setenv("HOME", "/myhome", 1);
  /* Setup terminal type. */
  setenv("TERM", "xterm-256color", 1);
  /* Blank out USER and LOGNAME. */
  setenv("USER", "", 1);
  setenv("LOGNAME", "", 1);

  TAR* tar;
  int ret = tar_open(&tar, "/mnt/tars/luadata.tar", NULL, O_RDONLY, 0, 0);
  assert(ret == 0);

  ret = tar_extract_all(tar, "/");
  assert(ret == 0);

  ret = tar_close(tar);
  assert(ret == 0);

  /* Ignore standard args passed via ppapi_simple */
  int new_argc = 0;
  char* new_argv[argc];
  int i;
  for (i = 0; i < argc; i++) {
    /* Ignore all args that start with -- other then --help and --version.
     * These are the only two long arguments that lua takes.  We assume
     * the aothers come from the html embed tag attributed.
     */
    if (!strncmp(argv[i], "--", 2)) {
      if (strcmp(argv[i], "--help") && strcmp(argv[i], "--version"))
        continue;
    }
    new_argv[new_argc++] = argv[i];
  }

  return lua_main(new_argc, new_argv);
}

PPAPI_SIMPLE_REGISTER_MAIN(lua_ppapi_main)
