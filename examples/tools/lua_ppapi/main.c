/* Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

#include <assert.h>
#include <libtar.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mount.h>

#include "ppapi_simple/ps_main.h"


int lua_main(int argc, char **argv);

int lua_ppapi_main(int argc, char **argv) {
  umount("/");
  mount("foo", "/", "memfs", 0, NULL);
  mkdir("/home", 0777);

  /* Setup home directory to a known location. */
  setenv("HOME", "/home", 1);
  /* Blank out USER and LOGNAME. */
  setenv("USER", "", 1);
  setenv("LOGNAME", "", 1);

  const char* data_url = getenv("LUA_DATA_URL");
  if (!data_url)
    data_url = "./";

  mount(data_url, "/mnt/http", "httpfs", 0,
       "allow_cross_origin_requests=true,allow_credentials=false");

  struct stat buf;
  if (stat("/mnt/http/luadata.tar", &buf) == 0) {
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
  }

  return lua_main(argc, argv);
}

PPAPI_SIMPLE_REGISTER_MAIN(lua_ppapi_main)
