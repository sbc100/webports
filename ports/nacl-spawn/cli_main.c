/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

/* Define a typical entry point for command line tools spawned by bash
 * (e.g., ls, objdump, and objdump). */

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "nacl_io/nacl_io.h"
#include "ppapi_simple/ps_main.h"

extern int nacl_main(int argc, char *argv[]);

int cli_main(int argc, char* argv[]) {
  umount("/");
  mount("", "/", "memfs", 0, NULL);

  mkdir("/home", 0777);
  mkdir("/tmp", 0777);
  mkdir("/bin", 0777);
  mkdir("/etc", 0777);
  mkdir("/mnt", 0777);
  mkdir("/mnt/http", 0777);
  mkdir("/mnt/html5", 0777);

  if (mount("/", "/mnt/html5", "html5fs", 0, "") != 0) {
    perror("Mounting HTML5 filesystem failed. Please use --unlimited-storage");
  }

  /* naclterm.js sends the current working directory using this
   * environment variable. */
  if (getenv("PWD"))
    chdir(getenv("PWD"));

  return nacl_main(argc, argv);
}

PPAPI_SIMPLE_REGISTER_MAIN(cli_main)
