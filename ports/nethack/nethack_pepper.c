/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <libtar.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "nacl_io/nacl_io.h"
#include "ppapi_simple/ps_main.h"

extern int nethack_main(int argc, char *argv[]);

static void setup_unix_environment(void) {
  mkdir("/usr", 0777);
  mkdir("/usr/games", 0777);

  TAR* tar;
  int ret = tar_open(&tar, "/mnt/http/nethack.tar", NULL, O_RDONLY, 0, 0);
  assert(ret == 0);

  ret = tar_extract_all(tar, "/usr/games");
  assert(ret == 0);

  ret = tar_close(tar);
  assert(ret == 0);

  // Setup config file.
  ret = chdir(getenv("HOME"));
  assert(ret == 0);
  if (access(".nethackrc", R_OK) < 0) {
    int fh = open(".nethackrc", O_CREAT | O_WRONLY);
    const char config[] = "OPTIONS=color\n";
    write(fh, config, sizeof(config) - 1);
    close(fh);
  }

  ret = chdir("/usr/games");
  assert(ret == 0);
}

int nacl_main(int argc, char* argv[]) {
  setup_unix_environment();
  return nethack_main(argc, argv);
}
