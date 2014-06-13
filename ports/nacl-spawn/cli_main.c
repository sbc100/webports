/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

/* Define a typical entry point for command line tools spawned by bash
 * (e.g., ls, objdump, and objdump). */

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "nacl_io/nacl_io.h"
#include "ppapi_simple/ps_main.h"

extern int nacl_main(int argc, char *argv[]);

int cli_main(int argc, char* argv[]) {
  umount("/");
  mount("", "/", "memfs", 0, NULL);

  // Setup common environment variables, but don't override those
  // set already by ppapi_simple.
  setenv("HOME", "/home/user", 0);
  setenv("PATH", "/bin", 0);
  setenv("USER", "user", 0);
  setenv("LOGNAME", "user", 0);

  const char* home = getenv("HOME");
  if (home == NULL) {
    home = "/home";
  }
  mkdir("/home", 0777);
  mkdir(home, 0777);
  mkdir("/tmp", 0777);
  mkdir("/bin", 0777);
  mkdir("/etc", 0777);
  mkdir("/mnt", 0777);
  mkdir("/mnt/http", 0777);
  mkdir("/mnt/html5", 0777);

  const char* data_url = getenv("NACL_DATA_URL");
  if (!data_url)
    data_url = "./";

  if (mount(data_url, "/mnt/http", "httpfs", 0, "") != 0) {
    perror("Mounting http filesystem in /mnt/http failed.");
    return 1;
  }

  if (mount("/", "/mnt/html5", "html5fs", 0, "type=PERSISTENT") != 0) {
    perror("Mounting HTML5 filesystem in /mnt/html5 failed.");
  }

  if (mount("/home", home, "html5fs", 0, "type=PERSISTENT") != 0) {
    fprintf(stderr, "Mounting HTML5 filesystem in %s failed.", home);
  }

  if (mount("/", "/tmp", "html5fs", 0, "type=TEMPORARY") != 0) {
    perror("Mounting HTML5 filesystem in /tmp failed.");
  }

  /* naclterm.js sends the current working directory using this
   * environment variable. */
  if (getenv("PWD"))
    chdir(getenv("PWD"));

  // Tell the NaCl architecture to /etc/bashrc of mingn.
#if defined(__x86_64__)
  static const char kNaClArch[] = "x86_64";
#elif defined(__i686__)
  static const char kNaClArch[] = "i686";
#elif defined(__arm__)
  static const char kNaClArch[] = "arm";
#elif defined(__pnacl__)
  static const char kNaClArch[] = "pnacl";
#else
# error "Unknown architecture"
#endif
  setenv("NACL_ARCH", kNaClArch, 1);

  setlocale(LC_CTYPE, "");
  return nacl_main(argc, argv);
}

PPAPI_SIMPLE_REGISTER_MAIN(cli_main)
