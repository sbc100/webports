/*
 * Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/module.h>
#include <sys/mount.h>

#include "nacl_io/nacl_io.h"
#include "ppapi_simple/ps_main.h"

extern "C" int gdb_nacl_main(int argc, char *argv[]);

int gdb_pepper_main(int argc, char* argv[]) {
  umount("/");
  mount("foo", "/", "memfs", 0, NULL);

  const char *argv_gdb[] = {"gdb"};
  return gdb_nacl_main(1, const_cast<char**>(argv_gdb));
}

PPAPI_SIMPLE_REGISTER_MAIN(gdb_pepper_main)
