/* Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

#include <Python.h>
#include <libtar.h>
#include <locale.h>
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
      printf("error extracting %s\n", filename);
      return 1;
    }

    ret = tar_close(tar);
    assert(ret == 0);
  }

  // Setup environment variables
  setenv("HOME", "/home", 1);
  setenv("PATH", "/bin", 1);
  setenv("USER", "user", 1);
  setenv("LOGNAME", "user", 1);

  setlocale(LC_CTYPE, "");
  return 0;
}

int nacl_main(int argc, char **argv) {
  printf("Extracting: %s ...\n", DATA_FILE);
  if (setup_unix_environment(DATA_FILE))
    return -1;

  return Py_Main(argc, argv);
}
