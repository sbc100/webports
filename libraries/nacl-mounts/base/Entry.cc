/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <errno.h>
#include <irt.h>
#ifdef __GLIBC__
#include <irt_syscalls.h>
#endif
#include <string.h>
#include <sys/mman.h>
#include "base/nacl_dirent.h"
#include "Entry.h"
#include "KernelProxy.h"
#include "util/DebugPrint.h"

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
  DECLARE_STRUCT(net);
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

#ifdef __GLIBC__
  DECLARE(filepath, chdir);
  DECLARE(filepath, rmdir);
  DECLARE(filepath, mkdir);
  DECLARE(filepath, getcwd);

  DECLARE(net, select);
  DECLARE(net, socket);
  DECLARE(net, accept);
  DECLARE(net, bind);
  DECLARE(net, listen);
  DECLARE(net, connect);
  DECLARE(net, send);
  DECLARE(net, sendto);
  DECLARE(net, sendmsg);
  DECLARE(net, recv);
  DECLARE(net, recvfrom);
  DECLARE(net, recvmsg);
  DECLARE(net, getpeername);
  DECLARE(net, getsockname);
  DECLARE(net, getsockopt);
  DECLARE(net, setsockopt);
  DECLARE(net, socketpair);
  DECLARE(net, shutdown);
  DECLARE(net, epoll_create);
  DECLARE(net, epoll_ctl);
  DECLARE(net, epoll_wait);
  DECLARE(net, epoll_pwait);
  DECLARE(net, poll);
  DECLARE(net, ppoll);
#endif

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

  struct hostent* gethostbyname(const char* name) {
    return kp->gethostbyname(name);
  }

  int unlink(const char *path) {
    return kp->unlink(path);
  }

  ssize_t __real_read(int fd, void *buf, size_t count) {
    if (REAL(read)) {
      size_t nread;
      int error = REAL(read)(fd, buf, count, &nread);
      if (error) {
        errno = error;
        return -1;
      }
      return (ssize_t)nread;
    } else {
      errno = EIO;
      return -1;
    }
  }

  ssize_t __real_write(int fd, const void *buf, size_t count) {
    if (REAL(write)) {
      size_t nwrote;
      int error = REAL(write)(fd, buf, count, &nwrote);
      if (error) {
        errno = error;
        return -1;
      }
      return (ssize_t)nwrote;
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

  char* WRAP(getcwd) (char* buf, size_t size) {
    std::string b;
    if (!kp->getcwd(&b, size-1)) {
      return NULL;
    }
    return to_c(b, buf);
  }

#ifdef __GLIBC__
  int WRAP(rmdir) (const char* pathname) {
    return (kp->rmdir(pathname) < 0) ? errno : 0;
  }

  int WRAP(chdir) (const char* pathname) {
    return (kp->chdir(pathname) < 0) ? errno : 0;
  }

  int WRAP(mkdir) (const char* pathname, mode_t mode) {
    return (kp->mkdir(pathname, mode) < 0) ? errno : 0;
  }

  int WRAP(select) (int nfds, fd_set* readfds, fd_set* writefds,
                  fd_set* exceptfds, const struct timeval* tv, int *count) {
    *count = kp->select(nfds, readfds, writefds, exceptfds, tv);
    return (*count < 0) ? errno : 0;
  }

  int WRAP(socket) (int domain, int type, int protocol, int* sd) {
    *sd = kp->socket(domain, type, protocol);
    return (*sd < 0) ? errno : 0;
  }

  int WRAP(accept) (int sockfd, struct sockaddr* addr, socklen_t* addrlen,
                    int* ret) {
    *ret = kp->accept(sockfd, addr, addrlen);
    return (*ret < 0) ? errno : 0;
  }

  int WRAP(bind) (int sockfd, const struct sockaddr* addr, socklen_t addrlen) {
    return (kp->bind(sockfd, addr, addrlen) < 0) ? errno : 0;
  }

  int WRAP(listen) (int sockfd, int backlog) {
    return (kp->listen(sockfd, backlog) < 0) ? errno : 0;
  }

  int WRAP(connect) (int sockfd, const struct sockaddr* addr,
                     socklen_t addrlen) {
    return (kp->connect(sockfd, addr, addrlen) < 0) ? errno : 0;
  }

  int WRAP(send) (int sockfd, const void *buf, size_t len, int flags,
                  int* ret) {
    *ret = kp->send(sockfd, buf, len, flags);
    return (*ret < 0) ? errno : 0;
  }

  int WRAP(sendto) (int sockfd, const void *buf, size_t len, int flags,
                    const struct sockaddr *dest_addr, socklen_t addrlen,
                    int* ret) {
    *ret = kp->sendto(sockfd, buf, len, flags, dest_addr, addrlen);
    return (*ret < 0) ? errno : 0;
  }

  int WRAP(sendmsg) (int sockfd, const struct msghdr *msg, int flags,
                     int* ret) {
    *ret = kp->sendmsg(sockfd, msg, flags);
    return (*ret < 0) ? errno : 0;
  }

  int WRAP(recv) (int sockfd, void *buf, size_t len, int flags, int* ret) {
    *ret = kp->recv(sockfd, buf, len, flags);
    return (*ret < 0) ? errno : 0;
  }

  int WRAP(recvfrom) (int sockfd, void *buf, size_t len, int flags,
                struct sockaddr *src_addr, socklen_t *addrlen, int* ret) {
    *ret = kp->recvfrom(sockfd, buf, len, flags, src_addr, addrlen);
    return (*ret < 0) ? errno : 0;
  }

  int WRAP(recvmsg) (int sockfd, struct msghdr *msg, int flags, int* ret) {
    *ret = kp->recvmsg(sockfd, msg, flags);
    return (*ret < 0) ? errno : 0;
  }

  struct hostent* WRAP(gethostbyname) (const char* name) {
    return kp->gethostbyname(name);
  }


  int WRAP(getsockname) (int sockfd, struct sockaddr* addr,
                         socklen_t* addrlen) {
    return (kp->getsockname(sockfd, addr, addrlen)) < 0 ? errno : 0;
  }

  int WRAP(getpeername) (int sockfd, struct sockaddr* addr,
                         socklen_t* addrlen) {
    return (kp->getpeername(sockfd, addr, addrlen) < 0) ? errno : 0;
  }

  int WRAP(setsockopt) (int sockfd, int level, int optname, const void *optval,
                        socklen_t optlen) {
    return (kp->setsockopt(sockfd, level, optname, optval, optlen) < 0)
      ? errno : 0;
  }

  int WRAP(getsockopt) (int sockfd, int level, int optname, void *optval,
                            socklen_t* optlen) {
    return (kp->getsockopt(sockfd, level, optname, optval, optlen) < 0)
      ? errno : 0;
  }

  int WRAP(socketpair) (int domain, int type, int protocol, int sv[2]) {
    return (kp->socketpair(domain, type, protocol, sv) < 0) ? errno : 0;
  }

  int WRAP(shutdown) (int sockfd, int how) {
    return (kp->shutdown(sockfd, how) < 0) ? errno : 0;
  }

#endif
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
#ifdef __GLIBC__
      DO_WRAP(filepath, chdir);
      DO_WRAP(filepath, mkdir);
      DO_WRAP(filepath, rmdir);
      DO_WRAP(filepath, getcwd);

      DO_WRAP(net, select);
      DO_WRAP(net, socket);
      DO_WRAP(net, accept);
      DO_WRAP(net, bind);
      DO_WRAP(net, listen);
      DO_WRAP(net, connect);
      DO_WRAP(net, send);
      DO_WRAP(net, sendto);
      DO_WRAP(net, sendmsg);
      DO_WRAP(net, recv);
      DO_WRAP(net, recvfrom);
      DO_WRAP(net, recvmsg);
      DO_WRAP(net, getpeername);
      DO_WRAP(net, getsockname);
      DO_WRAP(net, getsockopt);
      DO_WRAP(net, setsockopt);
      DO_WRAP(net, socketpair);
      DO_WRAP(net, shutdown);
#endif
    }
  } nacl_mounts_static_initializer;

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
