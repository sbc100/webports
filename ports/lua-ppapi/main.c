/* Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

#include <assert.h>
#include <fcntl.h>
#include <libtar.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <unistd.h>

#include "ppapi_simple/ps_main.h"

int lua_main(int argc, char **argv);

static int setup_unix_environment(const char* tarfile) {
  TAR* tar;
  char filename[PATH_MAX];
  strcpy(filename, "/mnt/http/");
  strcat(filename, tarfile);
  int ret = tar_open(&tar, filename, NULL, O_RDONLY, 0, 0);
  if (ret) {
    printf("error opening: %s\n", filename);
    return 1;
  }

  ret = tar_extract_all(tar, "/");
  if (ret) {
    printf("error extracting: %s\n", filename);
    return 1;
  }

  ret = tar_close(tar);
  assert(ret == 0);

  chdir("/lua-5.2.2-tests");

  return 0;
}

int nacl_main(int argc, char **argv) {
  if (setup_unix_environment("luadata.tar"))
    return 1;

  return lua_main(argc, argv);
}
