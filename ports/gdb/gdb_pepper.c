/*
 * Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <stdio.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/types.h>

#include "nacl_io/nacl_io.h"
#include "ppapi_simple/ps_main.h"

int gdb_nacl_main(int argc, char *argv[]);
int gdb_pepper_main(int argc, char *argv[]);

int gdb_pepper_main(int argc, char* argv[]) {
  umount("/");
  mount("foo", "/", "memfs", 0, NULL);

  return gdb_nacl_main(argc, argv);
}

PPAPI_SIMPLE_REGISTER_MAIN(gdb_pepper_main)
