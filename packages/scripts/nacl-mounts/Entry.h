/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_SCRIPTS_NACL_MOUNTS_ENTRY_H_
#define PACKAGES_SCRIPTS_NACL_MOUNTS_ENTRY_H_

#include <dirent.h>
#include <sys/stat.h>

// The following functions are wrapper functions for system calls which are
// passed to the KernelProxy instance.
extern "C" {
  int __wrap_chdir(const char *path);
  char *__wrap_getcwd(char *buf, size_t size);
  char *__wrap_getwd(char *buf);
  int __wrap_dup(int oldfd);

  int __wrap_chmod(const char *path, mode_t mode);
  int __wrap_stat(const char *path, struct stat *buf);
  int __wrap_mkdir(const char *path, mode_t mode);
  int __wrap_rmdir(const char *path);
  int __wrap_umount(const char *path);

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
}

#endif  // PACKAGES_SCRIPTS_NACL_MOUNTS_ENTRY_H_
