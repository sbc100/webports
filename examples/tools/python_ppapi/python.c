/* Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

#include <Python.h>
#include <libtar.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/mount.h>

#include "nacl_io/nacl_io.h"
#include "ppapi_simple/ps_main.h"

#ifdef __arm__
#define DATA_FILE "pydata_arm.tar"
#elif defined __i386__
#define DATA_FILE "pydata_x86_32.tar"
#elif defined __x86_64__
#define DATA_FILE "pydata_x86_64.tar"
#elif defined __pnacl__
#define DATA_FILE "pydata_pnacl.tar"
#else
#error "Unknown arch"
#endif

int python_main(int argc, char **argv) {
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

  printf("Extracting: %s ...\n", "/mnt/tars/" DATA_FILE);
  TAR* tar;
  int ret = tar_open(&tar, "/mnt/tars/" DATA_FILE, NULL, O_RDONLY, 0, 0);
  assert(ret == 0);

  ret = tar_extract_all(tar, "/");
  assert(ret == 0);

  ret = tar_close(tar);
  assert(ret == 0);

  return Py_Main(argc, argv);
}

PPAPI_SIMPLE_REGISTER_MAIN(python_main)
