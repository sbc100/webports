/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <errno.h>
#include <string.h>
#include "Entry.h"
#include "KernelProxy.h"

#ifndef MAXPATHLEN
#define MAXPATHLEN 256
#endif

extern "C" {
  ssize_t __real_write(int fd, const void *buf, size_t count);
}

KernelProxy *kp = KernelProxy::KPInstance();

int __wrap_chdir(const char *path) {
  return kp->chdir(path);
}

static char *to_c(const std::string& b, char *buf) {
  memset(buf, 0, b.length()+1);
  strncpy(buf, b.c_str(), b.length());
  return buf;
}

char *__wrap_getcwd(char *buf, size_t size) {
  std::string b;
  if (!kp->getcwd(&b, size-1)) {
    return NULL;
  }
  return to_c(b, buf);
}

char *__wrap_getwd(char *buf) {
  std::string b;
  if (!kp->getwd(&b) || b.length() >= MAXPATHLEN) {
    return NULL;
  }
  return to_c(b, buf);
}

int __wrap_dup(int oldfd) {
  return kp->dup(oldfd);
}

int __wrap_chmod(const char *path, mode_t mode) {
  return kp->chmod(path, mode);
}

int __wrap_stat(const char *path, struct stat *buf) {
  return kp->stat(path, buf);
}

int __wrap_mkdir(const char *path, mode_t mode) {
  return kp->mkdir(path, mode);
}

int __wrap_rmdir(const char *path) {
  return kp->chdir(path);
}

int __wrap_umount(const char *path) {
  return kp->umount(path);
}

int __wrap_mount(const char *type, const char *dir, int flags, void *data) {
  return kp->mount(dir, data);
}

ssize_t __wrap_read(int fd, void *buf, size_t nbyte) {
  return kp->read(fd, buf, nbyte);
}

ssize_t __wrap_write(int fd, const void *buf, size_t count) {
  return kp->write(fd, buf, count);
}

int __wrap_fstat(int fd, struct stat *buf) {
  return kp->fstat(fd, buf);
}

int __wrap_getdents(int fd, void *buf, unsigned int count) {
  return kp->getdents(fd, buf, count);
}

int __wrap_fsync(int fd) {
  return kp->fsync(fd);
}

int __wrap_isatty(int fd) {
  return kp->isatty(fd);
}

int __wrap_close(int fd) {
  return kp->close(fd);
}

off_t __wrap_lseek(int fd, off_t offset, int whence) {
  return kp->lseek(fd, offset, whence);
}

int __wrap_open(const char *path, int oflag, ...) {
  if (oflag & O_CREAT) {
    va_list argp;
    mode_t mode;
    va_start(argp, oflag);
    mode = va_arg(argp, int);
    va_end(argp);
    return kp->open(path, oflag, mode);
  }
  return kp->open(path, oflag, 0);
}

int __wrap_remove(const char *path) {
  return kp->remove(path);
}

int __wrap_access(const char *path, int amode) {
  return kp->access(path, amode);
}

int __wrap_ioctl(int fd, unsigned long request, ...) {
  return kp->ioctl(fd, request);
}

int __wrap_link(const char *path1, const char *path2) {
  return kp->link(path1, path2);
}

int __wrap_symlink(const char *path1, const char *path2) {
  return kp->symlink(path1, path2);
}

int __wrap_kill(pid_t pid, int sig) {
  return kp->kill(pid, sig);
}



// Several more, don't route to kernel proxy for now.

uid_t __wrap_getuid(void) {
  // Make up a user id.
  return 1001;
}

int __wrap_setuid(uid_t id) {
  return 0;
}

gid_t __wrap_getgid(void) {
  // Make up a group id.
  return 1002;
}

int __wrap_setgid(gid_t id) {
  return 0;
}

char *__wrap_getlogin(void) {
  return const_cast<char*>("nobody");
}

struct passwd *__wrap_getpwnam(const char *login) {
  // Not sure this is helpful, as its an error.
  return 0;
}

struct passwd *__wrap_getpwuid(uid_t uid) {
  // Not sure this is helpful, as its an error.
  return 0;
}

mode_t __wrap_umask(mode_t cmask) {
  return 0777;
}

int __wrap_unlink(const char *path) {
  // Always pretend to work for now.
  return 0;
}

struct utimbuf;

int __wrap_utime(const char *path, struct utimbuf const *times) {
  return 0;
}
