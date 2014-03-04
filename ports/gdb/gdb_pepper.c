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
  // TODO(bradnelson): Don't bake in the assumption of debugging only nethack.
  mkdir("/mnt", 0777);
  mount("http://localhost:5103/nethack-3.4.3/glibc",
        "/mnt/nethack", "httpfs", 0,
        "manifest=/nethack.manifest,"
        "allow_cross_origin_requests=true,allow_credentials=false");

  // TODO(bradnelson): Figure out why passing these in by -ex doesn't work.
  printf("These are the commands to debug nethack:\n\n");
  printf("nacl-manifest /mnt/nethack/nethack/nethack_debug.nmf\n");
  printf("set directories /mnt/nethack/nethack_src/src\n");
  printf("break nethack_main\n");
  printf("target remote :4014\n");
  printf("cont\n");
  printf("\n");

  return gdb_nacl_main(argc, argv);
}

PPAPI_SIMPLE_REGISTER_MAIN(gdb_pepper_main)
