/* Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

#undef RUBY_EXPORT
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <libtar.h>
#include <locale.h>
#include <ruby.h>
#include <stdio.h>
#include <sys/mount.h>

#include "nacl_io/nacl_io.h"
#include "ppapi_simple/ps_main.h"

#ifdef __x86_64__
#define NACL_ARCH "x86_64"
#elif defined __i686__
#define NACL_ARCH "x86_32"
#elif defined __arm__
#define NACL_ARCH "arm"
#elif defined __pnacl__
#define NACL_ARCH "pnacl"
#else
#error "unknown arch"
#endif

#define DATA_ARCHIVE "/mnt/http/rbdata-" NACL_ARCH ".tar"

int ruby_main(int argc, char **argv) {
  int ret = umount("/");
  assert(ret == 0);

  ret = mount("foo", "/", "memfs", 0, NULL);
  assert(ret == 0);

  ret = mount("./", "/mnt/http", "httpfs", 0, NULL);
  assert(ret == 0);

  ret = mkdir("/home", 0777);
  assert(ret == 0);

  /* Setup home directory to a known location. */
  ret = setenv("HOME", "/home", 1);
  assert(ret == 0);

  /* Blank out USER and LOGNAME. */
  ret = setenv("USER", "", 1);
  assert(ret == 0);
  ret = setenv("LOGNAME", "", 1);
  assert(ret == 0);

  TAR* tar;
  printf("Extracting: %s ...\n", DATA_ARCHIVE);
  ret = tar_open(&tar, DATA_ARCHIVE, NULL, O_RDONLY, 0, 0);
  assert(ret == 0);

  ret = tar_extract_all(tar, "/");
  assert(ret == 0);

  ret = tar_close(tar);
  assert(ret == 0);

  printf("Launching irb ...\n");

  setlocale(LC_CTYPE, "");

  ruby_sysinit(&argc, &argv);
  {
    RUBY_INIT_STACK;
    ruby_init();
    return ruby_run_node(ruby_options(argc, argv));
  }
}

PPAPI_SIMPLE_REGISTER_MAIN(ruby_main)
