/* Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

#include <assert.h>
#include <fcntl.h>
#include <libtar.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <unistd.h>

#include "ppapi_simple/ps_main.h"


int lua_main(int argc, char **argv);

int lua_ppapi_main(int argc, char **argv) {
  umount("/");
  mount("foo", "/", "memfs", 0, NULL);
  mkdir("/home", 0777);
  mkdir("/tmp", 0777);

  setenv("HOME", "/home", 1);
  setenv("PATH", "/bin", 1);
  setenv("USER", "user", 1);
  setenv("LOGNAME", "user", 1);

  const char* data_url = getenv("LUA_DATA_URL");
  if (!data_url)
    data_url = "./";

  mount(data_url, "/mnt/http", "httpfs", 0,
        "allow_cross_origin_requests=true,allow_credentials=false");

  printf("Extracting luadata.tar\n");
  TAR* tar;
  int ret = tar_open(&tar, "/mnt/http/luadata.tar", NULL, O_RDONLY, 0, 0);
    if (ret) {
    printf("Error opening luadata.tar\n");
    return 1;
  }

  ret = tar_extract_all(tar, "/");
  if (ret) {
    printf("Error extracting luadata.tar\n");
    return 1;
  }

  ret = tar_close(tar);
  assert(ret == 0);

  chdir("/lua-5.2.2-tests");

  return lua_main(argc, argv);
}

PPAPI_SIMPLE_REGISTER_MAIN(lua_ppapi_main)
