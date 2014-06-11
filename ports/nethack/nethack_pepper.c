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
  // Rely on installed files for MinGN.
  char* mingn = getenv("MINGN");
  if (mingn && strcmp(mingn, "0") != 0) {
    return;
  }

  umount("/");
  mount("foo", "/", "memfs", 0, NULL);
  mount("./", "/tars", "httpfs", 0, NULL);

  /* Setup home directory to a known location. */
  setenv("HOME", "/home", 1);
  /* Blank out USER and LOGNAME. */
  setenv("USER", "", 1);
  setenv("LOGNAME", "", 1);

  mkdir("/usr", 0777);
  mkdir("/usr/games", 0777);
  chdir("/usr/games");

  TAR* tar;
  int ret = tar_open(&tar, "/tars/nethack.tar", NULL, O_RDONLY, 0, 0);
  assert(ret == 0);

  ret = tar_extract_all(tar, "/usr/games");
  assert(ret == 0);

  ret = tar_close(tar);
  assert(ret == 0);

  // Setup config file.
  mkdir("/home", 0777);
  int fh = open("/home/.nethackrc", O_CREAT | O_WRONLY);
  const char config[] = "OPTIONS=color\n";
  write(fh, config, sizeof(config) - 1);
  close(fh);
}

int nacl_main(int argc, char* argv[]) {
  setup_unix_environment();
  return nethack_main(argc, argv);
}
