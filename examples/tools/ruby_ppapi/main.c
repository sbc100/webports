/* Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

#undef RUBY_EXPORT
#include <assert.h>
#include <libtar.h>
#include <locale.h>
#include <fcntl.h>
#include "ruby.h"

#include "nacl_io/nacl_io.h"
#include "ppapi_simple/ps_main.h"

#ifdef __x86_64__
#define NACL_ARCH "x86_64"
#elif defined __i686__
#define NACL_ARCH "x86_32"
#elif defined __arm__
#define NACL_ARCH "arm"
#else
#error "unknown arch"
#endif

#define DATA_ARCHIVE "/mnt/tars/rbdata-" NACL_ARCH ".tar"

int
ruby_main(int argc, char **argv) {
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
  int ret = tar_open(&tar, DATA_ARCHIVE, NULL, O_RDONLY, 0, 0);
  assert(ret == 0);

  ret = tar_extract_all(tar, "/");
  assert(ret == 0);

  ret = tar_close(tar);
  assert(ret == 0);

  setlocale(LC_CTYPE, "");

  ruby_sysinit(&argc, &argv);
  {
    RUBY_INIT_STACK;
    ruby_init();
    return ruby_run_node(ruby_options(argc, argv));
  }
}

PPAPI_SIMPLE_REGISTER_MAIN(ruby_main)
