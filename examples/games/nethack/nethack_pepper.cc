/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <errno.h>
#include <fcntl.h>
#include <libtar.h>
#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/module.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <sys/mount.h>

#include "nacl_io/nacl_io.h"
#include "ppapi_simple/ps_main.h"

extern "C" int nethack_main(int argc, char *argv[]);

int nethack_pepper_main(int argc, char* argv[]) {
  umount("/");
  mount("foo", "/", "memfs", 0, NULL);
  mount("./", "/tars", "httpfs", 0, NULL);

  /* Setup home directory to a known location. */
  setenv("HOME", "/myhome", 1);
  /* Setup terminal type. */
  setenv("TERM", "xterm-256color", 1);
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
  {
    mkdir("/myhome", 0777);
    int fh = open("/myhome/.nethackrc", O_CREAT | O_WRONLY);
    const char config[] = "OPTIONS=color\n";
    write(fh, config, sizeof(config) - 1);
    close(fh);
  }

  const char *argv_nethack[] = {"nethack"};
  return nethack_main(1, const_cast<char**>(argv_nethack));
}

PPAPI_SIMPLE_REGISTER_MAIN(nethack_pepper_main)
