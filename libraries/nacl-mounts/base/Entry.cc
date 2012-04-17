/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <errno.h>
#include <string.h>
#include "Entry.h"
#include "KernelProxy.h"

#include <sys/mman.h>

#include <irt.h>
#include "irt_syscalls.h"
#include "nacl_dirent.h"

static KernelProxy *kp = KernelProxy::KPInstance();

extern "C" {

#define REAL(name) __nacl_irt_##name##_real
#define WRAP(name) __nacl_irt_##name##_wrap
#ifdef __GLIBC__
#  define DECLARE_STRUCT(group)
#  define MUX(group, name) __nacl_irt_##name
#else
#  define STRUCT_NAME(group) __libnacl_irt_##group
#  define DECLARE_STRUCT(group) \
    extern struct nacl_irt_##group STRUCT_NAME(group);
#  define MUX(group, name) STRUCT_NAME(group).name
#endif
#define DECLARE(group, name) typeof(MUX(group, name)) REAL(name);
#define DO_WRAP(group, name) do { \
    REAL(name) = MUX(group, name); \
    MUX(group, name) = (typeof(REAL(name))) WRAP(name); \
  } while (0)

#ifndef __GLIBC__
  DECLARE_STRUCT(fdio);
  DECLARE_STRUCT(filename);
  DECLARE_STRUCT(memory);
#endif

  DECLARE(fdio, close);
  DECLARE(fdio, fstat);
  DECLARE(fdio, getdents);
  DECLARE(fdio, read);
  DECLARE(fdio, seek);
  DECLARE(fdio, write);
  DECLARE(filename, open);
  DECLARE(filename, stat);
  DECLARE(memory, mmap);

  static char *to_c(const std::string& b, char *buf) {
    memset(buf, 0, b.length()+1);
    strncpy(buf, b.c_str(), b.length());
    return buf;
  }

  char *getcwd(char *buf, size_t size) {
    std::string b;
    if (!kp->getcwd(&b, size-1)) {
      return NULL;
    }
    return to_c(b, buf);
  }

#ifndef MAXPATHLEN
#  define MAXPATHLEN 256
#endif
  char *getwd(char *buf) {
    std::string b;
    if (!kp->getwd(&b) || b.length() >= MAXPATHLEN) {
      return NULL;
    }
    return to_c(b, buf);
  }

  int fsync(int fd) {
    return kp->fsync(fd);
  }

  int isatty(int fd) {
    return kp->isatty(fd);
  }

  int chmod(const char *path, mode_t mode) {
    return kp->chmod(path, mode);
  }

  int mkdir(const char *path, mode_t mode) {
    return kp->mkdir(path, mode);
  }

  int rmdir(const char *path) {
    return kp->rmdir(path);
  }

  int umount(const char *path) {
    return kp->umount(path);
  }

  int mount(const char *source, const char *target,
      const char *filesystemtype, unsigned long mountflags,
      const void *data) {
    return kp->mount(target, (void *) data);
  }

  int remove(const char *path) {
    return kp->remove(path);
  }

  int chdir(const char *path) {
    return kp->chdir(path);
  }

  int access(const char *path, int amode) {
    return kp->access(path, amode);
  }

  int ioctl(int fd, unsigned long request, ...) {
    return kp->ioctl(fd, request);
  }

  int link(const char *path1, const char *path2) {
    return kp->link(path1, path2);
  }

  int symlink(const char *path1, const char *path2) {
    return kp->symlink(path1, path2);
  }

  int kill(pid_t pid, int sig) {
    return kp->kill(pid, sig);
  }

  int unlink(const char *path) {
    return kp->unlink(path);
  }

  ssize_t __real_read(int fd, void *buf, size_t count) {
    size_t nread;
    errno = REAL(read)(fd, buf, count, &nread);
    return errno == 0 ? (ssize_t)nread : -1;
  }

  ssize_t __real_write(int fd, const void *buf, size_t count) {
    if (REAL(write)) {
      size_t nwrote;
      errno = REAL(write)(fd, buf, count, &nwrote);
      fsync(fd);
      return errno == 0 ? (ssize_t)nwrote : -1;
    } else {
      errno = EIO;
      return -1;
    }
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
      return ((int (*)(int, struct nacl_abi_stat*)) REAL(fstat))(fd, nacl_buf);
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

  int WRAP(mmap)(void **addr, size_t len, int prot, int flags,
      int fd, nacl_abi_off_t off) {
    // Do not pass our fake descriptors to irt.
    // Also, it would make more sense to return ENODEV instead of ENOSYS,
    // but _nl_load_locale implementation in GLibC will only fallback to read()
    // when mmap() returns ENOSYS.
    if (flags & MAP_ANONYMOUS)
      return REAL(mmap)(addr, len, prot, flags, fd, off);
    else
      return ENOSYS;
  }

  static struct NaClMountsStaticInitializer {
    NaClMountsStaticInitializer() {
      DO_WRAP(fdio, close);
      DO_WRAP(fdio, fstat);
      DO_WRAP(fdio, getdents);
      DO_WRAP(fdio, read);
      DO_WRAP(fdio, seek);
      DO_WRAP(fdio, write);
      DO_WRAP(filename, open);
      DO_WRAP(filename, stat);
      DO_WRAP(memory, mmap);
    }
  } nacl_mounts_static_initializer;

};


#ifndef __GLIBC__


// Several more that newlib lacks, that don't route to kernel proxy for now.

extern "C" {

uid_t getuid(void) {
  // Match glibc's default.
  return -1;
}

int setuid(uid_t id) {
  errno = EPERM;
  return -1;
}

gid_t getgid(void) {
  // Match glibc's default.
  return -1;
}

int setgid(gid_t id) {
  errno = EPERM;
  return -1;
}

char *getlogin(void) {
  return const_cast<char*>("");
}

struct passwd *getpwnam(const char *login) {
  errno = ENOENT;
  return NULL;
}

struct passwd *getpwuid(uid_t uid) {
  errno = ENOENT;
  return NULL;
}

mode_t umask(mode_t cmask) {
  return 0777;
}

struct utimbuf;

int utime(const char *path, struct utimbuf const *times) {
  return 0;
}

void (*signal(int sig, void (*func)(int)))(int) {
  return reinterpret_cast<void(*)(int)>(-1);
}

};

#endif // !__GLIBC__
