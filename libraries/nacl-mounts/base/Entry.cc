/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <errno.h>
#include <string.h>
#include "Entry.h"
#include "KernelProxy.h"

#ifdef __GLIBC__

#include "irt_syscalls.h"
#include "nacl_dirent.h"

KernelProxy *kp = KernelProxy::KPInstance();

extern "C" {

#define DECLARE(name) typeof(__nacl_irt_##name) __nacl_irt_##name##_real;
#define DO_WRAP(name) do { \
    __nacl_irt_##name##_real = __nacl_irt_##name; \
    __nacl_irt_##name = __nacl_irt_##name##_wrap; \
  } while (0)
#define WRAP(name) __nacl_irt_##name##_wrap
#define REAL(name) __nacl_irt_##name##_real

  DECLARE(open);
  DECLARE(close);
  DECLARE(read);
  DECLARE(write);
  DECLARE(stat);
  DECLARE(fstat);
  DECLARE(getdents);
  DECLARE(seek);

  ssize_t __real_read(int fd, void *buf, size_t count) {
    size_t nread;
    errno = REAL(read)(fd, buf, count, &nread);
    return errno == 0 ? (ssize_t)nread : -1;
  }

  ssize_t __real_write(int fd, const void *buf, size_t count) {
    size_t nwrote;
    errno = REAL(write)(fd, buf, count, &nwrote);
    fsync(fd);
    return errno == 0 ? (ssize_t)nwrote : -1;
  }

  int WRAP(open)(const char *pathname, int oflag, mode_t cmode, int *newfd) {
    *newfd = kp->open(pathname, oflag, cmode);
    return (*newfd < 0) ? errno : 0;
  }

  int WRAP(close)(int fd) {
    int res = kp->close(fd);
    return (res < 0) ? errno : 0;
  }

  int WRAP(read)(int fd, void *buf, size_t count, size_t *nread) {
    *nread = kp->read(fd, buf, count);
    return (*nread < 0) ? errno : 0;
  }

  int WRAP(write)(int fd, const void *buf, size_t count, size_t *nwrote) {
    *nwrote = kp->write(fd, buf, count);
    return (*nwrote < 0) ? errno : 0;
  }

  static void stat_to_nacl_stat(const struct stat* buf,
      struct nacl_abi_stat *nacl_buf) {
    memset(nacl_buf, 0, sizeof(struct nacl_abi_stat));
    nacl_buf->nacl_abi_st_dev = buf->st_dev;
    nacl_buf->nacl_abi_st_ino = buf->st_ino;
    nacl_buf->nacl_abi_st_mode = buf->st_mode;
    nacl_buf->nacl_abi_st_nlink = buf->st_nlink;
    nacl_buf->nacl_abi_st_uid = buf->st_uid;
    nacl_buf->nacl_abi_st_gid = buf->st_gid;
    nacl_buf->nacl_abi_st_rdev = buf->st_rdev;
    nacl_buf->nacl_abi_st_size = buf->st_size;
    nacl_buf->nacl_abi_st_blksize = buf->st_blksize;
    nacl_buf->nacl_abi_st_blocks = buf->st_blocks;
    nacl_buf->nacl_abi_st_atime = buf->st_atime;
    nacl_buf->nacl_abi_st_mtime = buf->st_mtime;
    nacl_buf->nacl_abi_st_ctime = buf->st_ctime;
  }

  int WRAP(stat)(const char *pathname, struct nacl_abi_stat *nacl_buf) {
    struct stat buf;
    memset(&buf, 0, sizeof(struct stat));
    int res = kp->stat(pathname, &buf);
    if (res < 0)
      return errno;
    stat_to_nacl_stat(&buf, nacl_buf);
    return 0;
  }

  int WRAP(fstat)(int fd, struct nacl_abi_stat *nacl_buf) {
    if (fd < 3) {
      // segfault if fstat fails in this case
      return REAL(fstat)(fd, nacl_buf);
    }
    struct stat buf;
    memset(&buf, 0, sizeof(struct stat));
    int res = kp->fstat(fd, &buf);
    if (res < 0)
      return errno;
    stat_to_nacl_stat(&buf, nacl_buf);
    return 0;
  }

  static const int d_name_shift = offsetof (dirent, d_name) -
    offsetof (struct nacl_abi_dirent, nacl_abi_d_name);

  int WRAP(getdents)(int fd, dirent* nacl_buf, size_t nacl_count,
      size_t *nread) {
    int nacl_offset = 0;
    // "buf" contains dirent(s); "nacl_buf" contains nacl_abi_dirent(s).
    // nacl_abi_dirent(s) are smaller than dirent(s), so nacl_count bytes buffer
    // is enough
    char buf[nacl_count];
    int offset = 0;
    int count;

    count = kp->getdents(fd, buf, nacl_count);
    if (count < 0)
      return errno;

    while (offset < count) {
      dirent* d = (dirent*)(buf + offset);
      nacl_abi_dirent* nacl_d = (nacl_abi_dirent*)((char*)nacl_buf +
          nacl_offset);
      nacl_d->nacl_abi_d_ino = d->d_ino;
      nacl_d->nacl_abi_d_off = d->d_off;
      nacl_d->nacl_abi_d_reclen = d->d_reclen - d_name_shift;
      size_t d_name_len = d->d_reclen - offsetof(dirent, d_name);
      memcpy(nacl_d->nacl_abi_d_name, d->d_name, d_name_len);

      offset += d->d_reclen;
      nacl_offset += nacl_d->nacl_abi_d_reclen;
    }

    *nread = nacl_offset;
    return 0;
  }

  int WRAP(seek)(int fd, nacl_abi_off_t offset, int whence,
      nacl_abi_off_t *new_offset) {
    *new_offset = kp->lseek(fd, offset, whence);
    return *new_offset < 0 ? errno : 0;
  }
}

struct NaClMountsStaticInitializer {
  NaClMountsStaticInitializer() {
    DO_WRAP(open);
    DO_WRAP(close);
    DO_WRAP(read);
    DO_WRAP(write);
    DO_WRAP(stat);
    DO_WRAP(fstat);
    DO_WRAP(getdents);
    DO_WRAP(seek);
  }
} nacl_mounts_static_initializer;


#else // __GLIBC__


#ifndef MAXPATHLEN
#define MAXPATHLEN 256
#endif

extern "C" {
  ssize_t __real_write(int fd, const void *buf, size_t count);
}

KernelProxy *kp = KernelProxy::KPInstance();

int __wrap_fflush(FILE *f) {
  int fd = fileno(f);
  return kp->fsync(fd);
}

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
  return const_cast<char*>("");
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

void (*__wrap_signal(int sig, void (*func)(int)))(int) {
  return reinterpret_cast<void(*)(int)>(-1);
}

#endif // __GLIBC__
