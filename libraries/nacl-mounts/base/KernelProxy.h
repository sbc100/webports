/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_KERNELPROXY_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_KERNELPROXY_H_

#include <errno.h>
#ifdef __GLIBC__
#include <poll.h>
#endif
#include <pthread.h>
#ifdef __GLIBC__
#include <sys/epoll.h>
#endif
#include <sys/stat.h>
#include <string>
#include "../base/Mount.h"
#include "../base/MountManager.h"
#include "../util/Path.h"
#include "../util/SimpleAutoLock.h"
#include "../util/SlotAllocator.h"

// KernelProxy handles all of the system calls.  System calls are either
// (1) handled entirely by the KernelProxy, (2) processed by the
// KernelProxy and then passed to a Mount, or (3) proccessed by the
// KernelProxy using other system calls implemented by the Mount.
class KernelProxy {
 public:
  virtual ~KernelProxy() {}

  // Obtain the singleton instance of the kernel proxy.  If no instance
  // has been instantiated, one will be instantiated and returned.
  static KernelProxy *KPInstance();

  // System calls handled by KernelProxy (not mount-specific)
  int chdir(const std::string& path);
  bool getcwd(std::string *buf, size_t size);
  bool getwd(std::string *buf);
  int dup(int oldfd);

  // System calls that take a path as an argument:
  // The kernel proxy will look for the Node associated to the path.  To
  // find the node, the kernel proxy calls the corresponding mounts GetNode()
  // method.  The corresponding  method will be called.  If the node
  // cannot be found, errno is set and -1 is returned.
  int chmod(const std::string& path, mode_t mode);
  int stat(const std::string& path, struct stat *buf);
  int mkdir(const std::string& path, mode_t mode);
  int rmdir(const std::string& path);
  int umount(const std::string& path);
  int mount(const std::string& path, void *mount);

  // System calls that take a file descriptor as an argument:
  // The kernel proxy will determine to which mount the file
  // descriptor's corresponding file handle belongs.  The
  // associated mount's function will be called.
  ssize_t read(int fd, void *buf, size_t nbyte);
  ssize_t write(int fd, const void *buf, size_t nbyte);
  int fstat(int fd, struct stat *buf);
  int getdents(int fd, void *buf, unsigned int count);
  int fsync(int fd);
  int isatty(int fd);

  // System calls handled by KernelProxy that rely on mount-specific calls
  // close() calls the mount's Unref() if the file handle corresponding to
  // fd was open
  int close(int fd);
  // lseek() relies on the mount's Stat() to determine whether or not the
  // file handle corresponding to fd is a directory
  off_t lseek(int fd, off_t offset, int whence);
  // open() relies on the mount's Creat() if O_CREAT is specified.  open()
  // also relies on the mount's GetNode().
  int open(const std::string& path, int oflag, mode_t mode);
  // remove() uses the mount's GetNode() and Stat() to determine whether or
  // not the path corresponds to a directory or a file.  The mount's Rmdir()
  // or Unlink() is called accordingly.
  int remove(const std::string& path);
  // unlink() is a simple wrapper around the mount's Unlink function.
  int unlink(const std::string& path);
  // access() uses the Mount's Stat().
  int access(const std::string& path, int amode);

  // TODO(arbenson): implement the following system calls
  int ioctl(int fd, unsigned long request);
  int link(const std::string& path1, const std::string& path2);
  int symlink(const std::string& path1, const std::string& path2);
  int kill(pid_t pid, int sig);

#ifdef __GLIBC__
  // TODO(vissi): implement the following system calls
  int socket(int domain, int type, int protocol);
  int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
  int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
  int listen(int sockfd, int backlog);
  int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
  int send(int sockfd, const void *buf, size_t len, int flags);
  int sendmsg(int sockfd, const struct msghdr *msg, int flags);
  int sendto(int sockfd, const void *buf, size_t len, int flags,
             const struct sockaddr *dest_addr, socklen_t addrlen);
  int recv(int sockfd, void *buf, size_t len, int flags);
  int recvmsg(int sockfd, struct msghdr *msg, int flags);
  int recvfrom(int sockfd, void *buf, size_t len, int flags,
               struct sockaddr *dest_addr, socklen_t* addrlen);
  int select(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds,
             const struct timeval *timeout);
  int pselect(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds,
              const struct timeval *timeout, void* sigmask);
  int getpeername(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
  int getsockname(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
  int getsockopt(int sockfd, int level, int optname, void *optval,
                 socklen_t* optlen);
  int setsockopt(int sockfd, int level, int optname, const void *optval,
                 socklen_t optlen);
  int shutdown(int sockfd, int how);
  int epoll_create(int size);
  int epoll_create1(int flags);
  int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event);
  int epoll_wait(int epfd, struct epoll_event *events, int maxevents,
                 int timeout);
  int epoll_pwait(int epfd, struct epoll_event *events, int maxevents,
           int timeout, const sigset_t *sigmask, size_t sigset_size);
  int socketpair(int domain, int type, int protocol, int sv[2]);
  int poll(struct pollfd *fds, nfds_t nfds, int timeout);
  int ppoll(struct pollfd *fds, nfds_t nfds, const struct timespec *timeout,
            const sigset_t *sigmask, size_t sigset_size);
#endif
  MountManager *mm() { return &mm_; }

 private:
  struct FileDescriptor {
    // An index in open_files_ table
    int handle;
  };

  struct FileHandle {
    Mount *mount;
    ino_t node;
    off_t offset;
    int flags;
    int use_count;
    pthread_mutex_t lock;
  };

  Path cwd_;
  int max_path_len_;
  MountManager mm_;
  pthread_mutex_t kp_lock_;
  static KernelProxy *kp_instance_;

  SlotAllocator<FileDescriptor> fds_;
  SlotAllocator<FileHandle> open_files_;

  FileHandle *GetFileHandle(int fd);
  int OpenHandle(Mount *mount, const std::string& path, int oflag, mode_t mode);

  KernelProxy();
  static void Instantiate();
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_KERNELPROXY_H_
