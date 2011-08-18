/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_ENTRY_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_ENTRY_H_

#include <dirent.h>
#include <signal.h>
#include <sys/stat.h>

#include <stdio.h>
#include <unistd.h>

// The following functions are wrapper functions for system calls which are
// passed to the KernelProxy instance.
extern "C" {

  int __wrap_fflush(FILE *f);

  int __wrap_chdir(const char *path);
  char *__wrap_getcwd(char *buf, size_t size);
  char *__wrap_getwd(char *buf);
  int __wrap_dup(int oldfd);

  int __wrap_chmod(const char *path, mode_t mode);
  int __wrap_stat(const char *path, struct stat *buf);
  int __wrap_mkdir(const char *path, mode_t mode);
  int __wrap_rmdir(const char *path);
  int __wrap_umount(const char *path);
  int __wrap_mount(const char *type, const char *dir, int flags, void *data);

  ssize_t __wrap_read(int fd, void *buf, size_t nbyte);
  ssize_t __wrap_write(int fd, const void *buf, size_t nbyte);
  int __wrap_fstat(int fd, struct stat *buf);
  int __wrap_getdents(int fd, void *buf, unsigned int count);
  int __wrap_fsync(int fd);
  int __wrap_isatty(int fd);

  int __wrap_close(int fd);
  off_t __wrap_lseek(int fd, off_t offset, int whence);
  int __wrap_open(const char *path, int oflag, ...);
  int __wrap_remove(const char *path);
  int __wrap_access(const char *path, int amode);

  int __wrap_ioctl(int fd, unsigned long request, ...);
  int __wrap_link(const char *path1, const char *path2);
  int __wrap_symlink(const char *path1, const char *path2);
  int __wrap_kill(pid_t pid, int sig);

  uid_t __wrap_getuid(void);
  int __wrap_setuid(uid_t id);
  gid_t __wrap_getgid(void);
  int __wrap_setgid(gid_t id);
  char *__wrap_getlogin(void);
  struct passwd *__wrap_getpwnam(const char *login);
  struct passwd *__wrap_getpwuid(uid_t uid);
  mode_t __wrap_umask(mode_t cmask);
  int __wrap_unlink(const char *path);
  struct utimbuf;
  int __wrap_utime(const char *path, struct utimbuf const *times);
}

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_ENTRY_H_
