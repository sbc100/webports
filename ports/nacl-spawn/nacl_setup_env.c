/*
 * Copyright 2015 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <locale.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/types.h>

#include "ppapi/c/ppb_file_system.h"
#include "ppapi_simple/ps.h"
#include "ppapi_simple/ps_instance.h"
#include "ppapi_simple/ps_interface.h"

#include "nacl_main.h"
#include "nacl_spawn.h"


#define MAX_OLD_PIPES 100


/*
 * Get an environment variable as an int, or return -1 if the value cannot
 * be converted to an int.
 */
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
  int rtn =  mkdir(dir, 0777);
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

static void MountLocalFs(struct PP_Var mount_data) {
  bool available = nspawn_dict_getbool(mount_data, "available");

  if (!available) {
    return;
  } else {
    struct PP_Var filesystem = nspawn_dict_get(mount_data, "filesystem");
    PP_Resource filesystemResource =
        PSInterfaceVar()->VarToResource(filesystem);
    struct PP_Var filepath_var = nspawn_dict_get(mount_data, "fullPath");
    struct PP_Var mountpoint_var = nspawn_dict_get(mount_data, "mountPoint");

    uint32_t fp_len, mp_len;
    const char* filepath = PSInterfaceVar()->VarToUtf8(filepath_var,
                                                       &fp_len);
    const char* mountpoint = PSInterfaceVar()->VarToUtf8(mountpoint_var,
                                                         &mp_len);
    // TODO(gdeepti): Currently mount on the main thread always returns
    // without an error, crashes the nacl module and mkdir in /mnt/html5
    // does not work because we do not allow blocking calls on the main thread.
    // Move this off the main thread for better error checking.
    struct stat st;
    if (stat(mountpoint, &st) < 0) {
      mkdir_checked(mountpoint);
    }

    struct PP_Var status_var = nspawn_dict_create();
    char fs[1024];
    sprintf(fs, "filesystem_resource=%d\n", filesystemResource);

    if (do_mount(filepath, mountpoint, "html5fs", 0, fs) != 0) {
      fprintf(stderr, "Mounting HTML5 filesystem in %s failed.\n", filepath);
      nspawn_dict_setstring(status_var, "mount_status", "fail");
    } else {
      nspawn_dict_setstring(status_var, "mount_status", "success");
    }
    PSInterfaceMessaging()->PostMessage(PSGetInstanceId(), status_var);
    nspawn_var_release(filesystem);
    nspawn_var_release(filepath_var);
    nspawn_var_release(mountpoint_var);
  }
}

static void UnmountLocalFs(struct PP_Var mount_data) {
  bool mounted = nspawn_dict_getbool(mount_data, "mounted");
  struct PP_Var mountpoint_var = nspawn_dict_get(mount_data, "mountPoint");
  uint32_t mp_len;
  const char* mountpoint = PSInterfaceVar()->VarToUtf8(mountpoint_var, &mp_len);

  if (!mounted) {
    perror("Directory not mounted, unable to unmount");
  } else {
    struct PP_Var status_var = nspawn_dict_create();
    if (umount(mountpoint) != 0) {
      fprintf(stderr, "Unmounting filesystem %s failed.\n", mountpoint);
      nspawn_dict_setstring(status_var, "unmount_status", "fail");
    } else {
      nspawn_dict_setstring(status_var, "unmount_status", "success");
    }
    PSInterfaceMessaging()->PostMessage(PSGetInstanceId(), status_var);
    nspawn_var_release(status_var);
    nspawn_var_release(mountpoint_var);
  }
}

static void HandleMountMessage(struct PP_Var key,
                               struct PP_Var value,
                               void* user_data) {
  if (key.type != PP_VARTYPE_STRING || value.type != PP_VARTYPE_DICTIONARY) {
    fprintf(stderr, "Invalid parameter for HandleMountMessage\n");
    fprintf(stderr, "key type=%d\n", key.type);
    fprintf(stderr, "value type=%d\n", value.type);
    return;
  }

  MountLocalFs(value);
}


static void HandleUnmountMessage(struct PP_Var key,
                                 struct PP_Var value,
                                 void* user_data) {
  if (key.type != PP_VARTYPE_STRING || value.type != PP_VARTYPE_DICTIONARY) {
    fprintf(stderr, "Invalid parameter for HandleUnmountMessage\n");
    fprintf(stderr, "key type=%d\n", key.type);
    fprintf(stderr, "value type=%d\n", value.type);
    return;
  }

  UnmountLocalFs(value);
}

static void mountfs() {
  struct PP_Var req_var = nspawn_dict_create();
  nspawn_dict_setstring(req_var, "command", "nacl_mountfs");
  struct PP_Var result_dict_var = nspawn_send_request(req_var);

  MountLocalFs(result_dict_var);
  nspawn_var_release(result_dict_var);

  PSEventRegisterMessageHandler("mount", &HandleMountMessage, NULL);
  PSEventRegisterMessageHandler("unmount", &HandleUnmountMessage, NULL);
}

static void restore_pipes(void) {
  int old_pipes[MAX_OLD_PIPES][3];
  int old_pipe_count = 0;
  int count = 0;
  int i;
  for (;;) {
    char entry[100];
    snprintf(entry, sizeof entry, "NACL_SPAWN_FD_SETUP_%d", count++);
    const char *env_entry = getenv(entry);
    if (!env_entry) {
      break;
    }
    int fd, port, writer;
    if (sscanf(env_entry, "pipe:%d:%d:%d", &fd, &port, &writer) != 3) {
      unsetenv(entry);
      continue;
    }
    unsetenv(entry);
    /*
     * NOTE: This is necessary as the javascript assumes all instances
     * of an anonymous pipe will be from the same file object.
     * This allows nacl_io to do the reference counting.
     * naclprocess.js then merely tracks which processes are readers and
     * writers for a given pipe.
     */
    for (i = 0; i < old_pipe_count; ++i) {
      if (old_pipes[i][0] == port && old_pipes[i][1] == writer) {
        dup2(old_pipes[i][2], fd);
        break;
      }
    }
    if (i != old_pipe_count) continue;
    char path[100];
    sprintf(path, "/apipe/%d", port);
    int fd_tmp = open(path, (writer ? O_WRONLY : O_RDONLY));
    if (fd_tmp < 0) {
      fprintf(stderr, "Failed to created pipe on port %d\n", port);
      exit(1);
    }
    if (fd_tmp != fd) {
      dup2(fd_tmp, fd);
      close(fd_tmp);
    }
    if (old_pipe_count >= MAX_OLD_PIPES) {
      fprintf(stderr, "Too many old pipes to restore!\n");
      exit(1);
    }
    old_pipes[old_pipe_count][0] = port;
    old_pipes[old_pipe_count][1] = writer;
    old_pipes[old_pipe_count][2] = fd;
    ++old_pipe_count;
  }
}

void nacl_setup_env() {
  /*
   * If we running in sel_ldr then don't do any the filesystem/nacl_io
   * setup. We detect sel_ldr by the absence of the Pepper Instance.
   */
  if (PSGetInstanceId() == 0) {
    return;
  }

  umount("/");
  do_mount("", "/", "memfs", 0, NULL);

  nspawn_setup_anonymous_pipes();

  /*
   * Setup common environment variables, but don't override those
   * set already by ppapi_simple.
   */
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

  mountfs();

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
  // Use __i386__ rather then __i686__ since the latter is not defined
  // by i686-nacl-clang.
#elif defined(__i386__)
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

  nspawn_pid = getenv_as_int("NACL_PID");
  nspawn_ppid = getenv_as_int("NACL_PPID");

  restore_pipes();
}
