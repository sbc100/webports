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

#include "nacl_main.h"
#include "ppapi_simple/ps_main.h"

extern int nacl_main(int argc, char *argv[]);

int nacl_spawn_pid;
int nacl_spawn_ppid;

// Get an environment variable as an int, or return -1 if the value cannot
// be converted to an int.
static int getenv_as_int(const char *env) {
  const char* env_str = getenv(env);
  if (!env_str) {
    return -1;
  }
  errno = 0;
  int env_int = strtol(env_str, NULL, 0);
  if (errno) {
    return -1;
  }
  return env_int;
}

static int mkdir_checked(const char* dir) {
  int rtn =  mkdir(dir, S_IRWXU | S_IRWXG | S_IRWXO);
  if (rtn != 0) {
    fprintf(stderr, "mkdir '%s' failed: %s\n", dir, strerror(errno));
  }
  return rtn;
}

static int do_mount(const char *source, const char *target,
                    const char *filesystemtype, unsigned long mountflags,
                    const void *data) {
  NACL_LOG("mount[%s] '%s' at '%s'\n", filesystemtype, source, target);
  return mount(source, target, filesystemtype, mountflags, data);
}

extern "C" int cli_main(int argc, char* argv[]) {
  umount("/");
  do_mount("", "/", "memfs", 0, NULL);

  // Setup common environment variables, but don't override those
  // set already by ppapi_simple.
  setenv("HOME", "/home/user", 0);
  setenv("PATH", "/bin", 0);
  setenv("USER", "user", 0);
  setenv("LOGNAME", "user", 0);

  const char* home = getenv("HOME");
  mkdir_checked("/home");
  mkdir_checked(home);
  mkdir_checked("/tmp");
  mkdir_checked("/bin");
  mkdir_checked("/etc");
  mkdir_checked("/mnt");
  mkdir_checked("/mnt/http");
  mkdir_checked("/mnt/html5");

  const char* data_url = getenv("NACL_DATA_URL");
  if (!data_url)
    data_url = "./";
  NACL_LOG("NACL_DATA_URL=%s\n", data_url);

  const char* mount_flags = getenv("NACL_DATA_MOUNT_FLAGS");
  if (!mount_flags)
    mount_flags = "";
  NACL_LOG("NACL_DATA_MOUNT_FLAGS=%s\n", mount_flags);

  if (do_mount(data_url, "/mnt/http", "httpfs", 0, mount_flags) != 0) {
    perror("mounting http filesystem at /mnt/http failed");
  }

  if (do_mount("/", "/mnt/html5", "html5fs", 0, "type=PERSISTENT") != 0) {
    perror("Mounting HTML5 filesystem in /mnt/html5 failed");
  } else {
    mkdir("/mnt/html5/home", 0777);
    struct stat st;
    if (stat("/mnt/html5/home", &st) < 0 || !S_ISDIR(st.st_mode)) {
      perror("Unable to create home directory in persistent storage");
    } else {
      if (do_mount("/home", home, "html5fs", 0, "type=PERSISTENT") != 0) {
        fprintf(stderr, "Mounting HTML5 filesystem in %s failed.\n", home);
      }
    }
  }

  if (do_mount("/", "/tmp", "html5fs", 0, "type=TEMPORARY") != 0) {
    perror("Mounting HTML5 filesystem in /tmp failed");
  }

  /* naclprocess.js sends the current working directory using this
   * environment variable. */
  const char* pwd = getenv("PWD");
  if (pwd != NULL) {
    if (chdir(pwd)) {
      fprintf(stderr, "chdir() to %s failed: %s\n", pwd, strerror(errno));
    }
  }

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
  // Set NACL_ARCH with a guess if not set (0 == set if not already).
  setenv("NACL_ARCH", kNaClArch, 0);
  // Set NACL_BOOT_ARCH if not inherited from a parent (0 == set if not already
  // set). This will let us prefer PNaCl if we started with PNaCl (for tests
  // mainly).
  setenv("NACL_BOOT_ARCH", kNaClArch, 0);

  setlocale(LC_CTYPE, "");

  nacl_spawn_pid = getenv_as_int("NACL_PID");
  nacl_spawn_ppid = getenv_as_int("NACL_PPID");

  return nacl_main(argc, argv);
}

PPAPI_SIMPLE_REGISTER_MAIN(cli_main)
