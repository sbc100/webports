/*
 * Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <libtar.h>
#include <limits.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nacl_io/nacl_io.h"
#include "ppapi_simple/ps_main.h"

// The special NaCl entry point into emacs.
extern int nacl_emacs_main(int argc, char *argv[]);

static int setup_unix_environment(const char* tarfile) {
  // Extra tar achive from http filesystem.
  if (tarfile) {
    int ret;
    TAR* tar;
    char filename[PATH_MAX];
    strcpy(filename, "/mnt/http/");
    strcat(filename, tarfile);
    ret = tar_open(&tar, filename, NULL, O_RDONLY, 0, 0);
    if (ret) {
      printf("error opening %s\n", filename);
      return 1;
    }

    ret = tar_extract_all(tar, "/");
    if (ret) {
      // TODO(petewil): Remove next line before shipping
      printf("errno is %d\n", errno);
      printf("error extracting %s\n", filename);
      return 1;
    }

    ret = tar_close(tar);
    assert(ret == 0);
  }

  return 0;
}

int nacl_main(int argc, char* argv[]) {
  if (setup_unix_environment("emacs.tar"))
    return 1;
  return nacl_emacs_main(argc, argv);
}
