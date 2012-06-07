/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include "base/KernelProxy.h"
#include <assert.h>
#ifndef __GLIBC__
#include <nacl-mounts/net/newlib_compat.h>
#else
#include <netdb.h>
#include <netinet/in.h>
#endif
#include <sys/time.h>
#include <list>
#include <utility>
#include "console/ConsoleMount.h"
#include "dev/DevMount.h"
#include "MountManager.h"
#include "net/BaseSocketSubSystem.h"
#include "net/SocketSubSystem.h"
#include "util/DebugPrint.h"

static pthread_once_t kp_once_ = PTHREAD_ONCE_INIT;
KernelProxy *KernelProxy::kp_instance_;

#ifndef MAXPATHLEN
#define MAXPATHLEN 256
#endif

static const int64_t kMicrosecondsPerSecond = 1000 * 1000;
static const int64_t kNanosecondsPerMicrosecond = 1000;

KernelProxy::KernelProxy() {
  if (pthread_mutex_init(&kp_lock_, NULL)) assert(0);
  cwd_ = Path("/");
  mm_.Init();

  // Setup file descriptors 0, 1, and 2 for STDIN, STDOUT, and STDERR
  int ret = mkdir("/dev", 0777);
  assert(ret == 0);
  DevMount* dev_mount = new DevMount();
  ret = mm_.AddMount(dev_mount, "/dev");
  assert(ret == 0);
  ret = mkdir("/dev/fd", 0777);
  assert(ret == 0);
  ConsoleMount *console_mount = new ConsoleMount();
  ret = mm_.AddMount(console_mount, "/dev/fd");
  assert(ret == 0);
  int fd = open("/dev/fd/0", O_CREAT | O_RDWR, 0);
  assert(fd == 0);
  fd = open("/dev/fd/1", O_CREAT | O_RDWR, 0);
  assert(fd == 1);
  fd = open("/dev/fd/2", O_CREAT | O_RDWR, 0);
  assert(fd == 2);
}

void KernelProxy::SetSocketSubSystem(BaseSocketSubSystem* bss) {
  socket_subsystem_ = bss;
}

void KernelProxy::RemoveSocket(int fd) {
  this->close(fd);
}

int KernelProxy::AddSocket(Socket* stream) {
  SimpleAutoLock lock(&kp_lock_);

  // Setup file handle.
  int handle_slot = open_files_.Alloc();
  int fd = fds_.Alloc();
  FileDescriptor* file = fds_.At(fd);
  file->handle = handle_slot;
  FileHandle* handle = open_files_.At(handle_slot);

  // init should be safe because we have the kernel proxy lock
  if (pthread_mutex_init(&handle->lock, NULL)) assert(0);

  handle->mount = reinterpret_cast<Mount*>(NULL);
  handle->stream = reinterpret_cast<Socket*>(NULL);
  handle->use_count = 1;

  return fd;
}

KernelProxy *KernelProxy::KPInstance() {
  pthread_once(&kp_once_, Instantiate);
  return kp_instance_;
}

void KernelProxy::Instantiate() {
  assert(!kp_instance_);
  kp_instance_ = new KernelProxy();
}

static bool is_dir(Mount *mount, ino_t node) {
  struct stat st;
  if (0 != mount->Stat(node, &st)) {
    return false;
  }
  return S_ISDIR(st.st_mode);
}

int KernelProxy::chdir(const std::string& path) {
  std::pair<Mount *, std::string> m_and_p;

  // not supporting empty paths right now
  if (path.empty()) {
    errno = ENOENT;
    return -1;
  }

  SimpleAutoLock lock(&kp_lock_);

  Path p(path);
  if (path[0] != '/') {
    p = Path(cwd_.FormulatePath() + "/" + path);
  }

  struct stat buf;
  Mount *mount = mm_.GetNode(p.FormulatePath(), &buf);

  // check if node exists
  if (!mount) {
    errno = ENOENT;
    return -1;
  }
  // check that node is a directory
  if (!is_dir(mount, buf.st_ino)) {
    errno = ENOTDIR;
    return -1;
  }

  // update path
  m_and_p = mm_.GetMount(cwd_.FormulatePath());
  if (!(m_and_p.first)) {
    return -1;
  }
  cwd_ = p;
  return 0;
}

bool KernelProxy::getcwd(std::string *buf, size_t size) {
  if (size <= 0) {
    errno = EINVAL;
    return false;
  }
  if (size < cwd_.FormulatePath().length()) {
    errno = ERANGE;
    return false;
  }
  *buf = cwd_.FormulatePath();
  return true;
}

bool KernelProxy::getwd(std::string *buf) {
  return getcwd(buf, MAXPATHLEN);
}

int KernelProxy::link(const std::string& path1, const std::string& path2) {
  errno = ENOSYS;
  fprintf(stderr, "link has not been implemented!\n");
  assert(0);
  return -1;
}

int KernelProxy::symlink(const std::string& path1, const std::string& path2) {
  errno = ENOSYS;
  fprintf(stderr, "symlink has not been implemented!\n");
  assert(0);
  return -1;
}

static ssize_t GetFileLen(Mount *mount, ino_t node) {
  struct stat st;
  if (0 != mount->Stat(node, &st)) {
    return -1;
  }
  return (ssize_t) st.st_size;
}

int KernelProxy::OpenHandle(Mount *mount, const std::string& path,
                            int flags, mode_t mode) {
  if (path.empty()) {
    errno = ENOENT;
    return -1;
  }

  SimpleAutoLock lock(&kp_lock_);

  // OpenHandle() is only called by open().  open() handles relative paths by
  // prepending the current working directory to the path.  open() then
  // provides a relative path to the corresponding mount for Openhandle().
  // Thus, we should not to do any relative path checking in OpenHandle().
  struct stat st;
  bool ok = false;
  if (flags & O_CREAT) {
    if (0 == mount->Creat(path, mode, &st)) {
      ok = true;
    } else {
      if ((errno != EEXIST) ||
          (flags & O_EXCL)) {
        return -1;
      }
    }
  }
  if (!ok) {
    if (0 != mount->GetNode(path, &st)) {
      errno = ENOENT;
      return -1;
    }
  }

  mount->Ref(st.st_ino);
  mount->Ref();
  // Setup file handle.
  int handle_slot = open_files_.Alloc();
  int fd = fds_.Alloc();
  FileDescriptor* file = fds_.At(fd);
  file->handle = handle_slot;
  FileHandle* handle = open_files_.At(handle_slot);

  // init should be safe because we have the kernel proxy lock
  if (pthread_mutex_init(&handle->lock, NULL)) assert(0);

  handle->mount = mount;
  handle->stream = NULL;
  handle->node = st.st_ino;
  handle->flags = flags;
  handle->use_count = 1;

  if (flags & O_APPEND) {
    handle->offset = st.st_size;
  } else {
    handle->offset = 0;
  }

  return fd;
}

static __thread struct hostent* ghn_res = NULL;
static __thread char** ghn_addr_list = NULL;
static __thread char* ghn_item = NULL;

struct hostent* KernelProxy::gethostbyname(const char* name) {
  struct hostent *res = ghn_res;
  if (ghn_res == NULL) {
    res = (ghn_res = reinterpret_cast<struct hostent*>
        (malloc(sizeof(struct hostent))));
  }
  if (!res) return NULL;
  res->h_addr_list = ghn_addr_list == NULL
    ? (ghn_addr_list = reinterpret_cast<char**>(malloc(sizeof(char*) * 2)))
    : ghn_addr_list;
  if (!res->h_addr_list) return NULL;
  res->h_addr_list[0] = ghn_item == NULL
    ? (ghn_item = reinterpret_cast<char*>(malloc(sizeof(uint32_t))))
    : ghn_item;
  if (!res->h_addr_list[0]) return NULL;
  *(reinterpret_cast<uint32_t*>(res->h_addr_list[0])) =
    socket_subsystem_->gethostbyname(name);
  res->h_addr_list[1] = NULL;
  res->h_length = sizeof(uint32_t);
  return res;
}

int KernelProxy::getaddrinfo(const char* hostname, const char* servname,
                const struct addrinfo* hints, struct addrinfo** res) {
  return socket_subsystem_->getaddrinfo(
      hostname, servname, hints, res);
}

void KernelProxy::freeaddrinfo(struct addrinfo* ai) {
  return socket_subsystem_->freeaddrinfo(ai);
}

int KernelProxy::getnameinfo(const struct sockaddr *sa, socklen_t salen,
                char* host, socklen_t hostlen,
                char* serv, socklen_t servlen, unsigned int flags) {
  return socket_subsystem_->getnameinfo(
      sa, salen, host, hostlen, serv, servlen, flags);
}

int KernelProxy::open(const std::string& path, int flags, mode_t mode) {
  if (path.empty()) {
    errno = EINVAL;
    return -1;
  }

  Path p(path);
  if (path[0] != '/') {
    p = Path(cwd_.FormulatePath() + "/" + path);
  }

  std::pair<Mount *, std::string> m_and_p =
    mm_.GetMount(p.FormulatePath());

  if (!(m_and_p.first)) {
    errno = ENOENT;
    return -1;
  }

  return OpenHandle(m_and_p.first, m_and_p.second, flags, mode);
}

int KernelProxy::close(int fd) {
  SimpleAutoLock lock(&kp_lock_);

  FileDescriptor* file = fds_.At(fd);
  if (file == NULL) {
    errno = EBADF;
    return -1;
  }
  int h = file->handle;
  fds_.Free(fd);
  FileHandle* handle = open_files_.At(h);
  if (handle == NULL) {
    errno = EBADF;
    return -1;
  }
  handle->use_count--;
  ino_t node = handle->node;
  if (handle->mount) {
    Mount* mount = handle->mount;
    if (handle->use_count <= 0) {
      open_files_.Free(h);
      mount->Unref(node);
    }
    mount->Unref();
  } else {
    Socket* stream = handle->stream;
    socket_subsystem_->close(stream);
    if (handle->use_count <= 0) {
      open_files_.Free(h);
    }
    return 0;
  }
  return 0;
}

ssize_t KernelProxy::read(int fd, void *buf, size_t count) {
  FileHandle* handle;
  // check if fd is valid and handle exists
  if (!(handle = GetFileHandle(fd))) {
    errno = EBADF;
    return -1;
  }

  if (handle->mount) {
    SimpleAutoLock(&handle->lock);
    // Check that this file handle can be read from.
    if ((handle->flags & O_ACCMODE) == O_WRONLY ||
        is_dir(handle->mount, handle->node)) {
      errno = EBADF;
      return -1;
    }

    ssize_t n = handle->mount->Read(handle->node, handle->offset, buf, count);
    if (n > 0) {
      handle->offset += n;
    }
    return n;
  } else if (handle->stream) {
    // TODO(vissi): more elaborate implementation
    return recv(fd, buf, count, 0);
  }
  errno = EBADF;
  return -1;
}

ssize_t KernelProxy::write(int fd, const void *buf, size_t count) {
  FileHandle* handle;

  // check if fd is valid and handle exists
  if (!(handle = GetFileHandle(fd))) {
    errno = EBADF;
    return -1;
  }

  if (handle->mount) {
    SimpleAutoLock(&handle->lock);
    // Check that this file handle can be written to.
    if ((handle->flags & O_ACCMODE) == O_RDONLY ||
        is_dir(handle->mount, handle->node)) {
      errno = EBADF;
      return -1;
    }

    ssize_t n = handle->mount->Write(handle->node, handle->offset, buf, count);

    if (n > 0) {
      handle->offset += n;
    }
    return n;
  } else if (handle->stream) {
    // TODO(vissi): more elaborate implementation
    return send(fd, buf, count, 0);
  }
  errno = EBADF;
  return -1;
}

int KernelProxy::fstat(int fd, struct stat *buf) {
  FileHandle* handle;

  // check if fd is valid and handle exists
  if (!(handle = GetFileHandle(fd))) {
    errno = EBADF;
    return -1;
  }
  SimpleAutoLock(&handle->lock);
  return handle->mount->Stat(handle->node, buf);
}

int KernelProxy::ioctl(int fd, unsigned long request) {
  errno = ENOSYS;
  fprintf(stderr, "ioctl has not been implemented!\n");
  assert(0);
  return -1;
}

int KernelProxy::kill(pid_t pid, int sig) {
  errno = ENOSYS;
  fprintf(stderr, "kill has not been implemented!\n");
  assert(0);
  return -1;
}

int KernelProxy::getdents(int fd, void *buf, unsigned int count) {
  FileHandle* handle;

  // check if fd is valid and handle exists
  if (!(handle = GetFileHandle(fd))) {
    errno = EBADF;
    return -1;
  }

  SimpleAutoLock(&handle->lock);

  int ret = handle->mount->Getdents(handle->node, handle->offset,
                                    (struct dirent*)buf, count);

  if (ret != -1) {
    // TODO(bradnelson): think of a better interface for Mount::Getdents.
    // http://code.google.com/p/naclports/issues/detail?id=18
    handle->offset += ret / sizeof(struct dirent);
  }
  return ret;
}

int KernelProxy::fsync(int fd) {
  FileHandle* handle;

  if (!(handle = GetFileHandle(fd))) {
    errno = EBADF;
    return -1;
  }
  SimpleAutoLock(&handle->lock);
  return handle->mount->Fsync(handle->node);
}

int KernelProxy::isatty(int fd) {
  FileHandle* handle;

  if (!(handle = GetFileHandle(fd))) {
    errno = EBADF;
    return 0;
  }
  return handle->mount->Isatty(handle->node);
}

int KernelProxy::dup2(int fd, int newfd) {
  SimpleAutoLock lock(&kp_lock_);
  int handle_slot = fds_.At(fd)->handle;
  if (fds_.AllocAt(fd) != fd) return -1;
  FileDescriptor* file = fds_.At(newfd);
  file->handle = handle_slot;
  return 0;
}

int KernelProxy::IsReady(int nfds, fd_set* fds,
    bool (Socket::*is_ready)(), bool apply) {
  if (!fds)
    return 0;

  int nset = 0;
  for (int i = 0; i < nfds; i++) {
    if (FD_ISSET(i, fds)) {
      Socket* stream = GetFileHandle(i) > 0 ?
        GetFileHandle(i)->stream : NULL;
      if (!stream)
        return -1;
      if ((stream->*is_ready)()) {
        if (!apply)
          return 1;
        else
          nset++;
      } else {
        if (apply)
          FD_CLR(i, fds);
      }
    }
  }
  return nset;
}

int KernelProxy::dup(int oldfd) {
  SimpleAutoLock lock(&kp_lock_);

  FileHandle* fh = GetFileHandle(oldfd);
  if (!fh) {
    errno = EBADF;
    return -1;
  }
  if (fh->mount == NULL) {
    Socket* stream = GetFileHandle(oldfd) > 0
      ? GetFileHandle(oldfd)->stream : NULL;
    if (!stream)
      return EBADF;
    SimpleAutoLock lock(&kp_lock_);
    int handle_slot = fds_.At(oldfd)->handle;
    int newfd = fds_.Alloc();
    FileDescriptor* file = fds_.At(newfd);
    file->handle = handle_slot;
    return newfd;
  }
  FileDescriptor* oldfile = fds_.At(oldfd);
  if (oldfile == NULL) {
    errno = EBADF;
    return -1;
  }
  int newfd = fds_.Alloc();
  FileDescriptor *newfile = fds_.At(newfd);
  int h = oldfile->handle;
  newfile->handle = h;
  FileHandle* handle = open_files_.At(h);
  // init should be safe because we have the kernel proxy lock
  if (pthread_mutex_init(&handle->lock, NULL)) assert(0);

  if (handle == NULL) {
    errno = EBADF;
    return -1;
  }
  ++handle->use_count;
  handle->mount->Ref(handle->node);
  handle->mount->Ref();
  return newfd;
}

off_t KernelProxy::lseek(int fd, off_t offset, int whence) {
  FileHandle* handle;
  // check if fd is valid and handle exists
  if (!(handle = GetFileHandle(fd))) {
    errno = EBADF;
    return -1;
  }

  SimpleAutoLock(&handle->lock);

  off_t next;
  ssize_t len;

  // Check that it isn't a directory.
  if (is_dir(handle->mount, handle->node)) {
    errno = EBADF;
    return -1;
  }
  switch (whence) {
  case SEEK_SET:
    next = offset;
    break;
  case SEEK_CUR:
    next = handle->offset + offset;
    // TODO(arbenson): handle EOVERFLOW if too big.
    break;
  case SEEK_END:
    // TODO(krasin, arbenson): FileHandle should store file len.
    len = GetFileLen(handle->mount, handle->node);
    if (len == -1) {
      return -1;
    }
    next = static_cast<size_t>(len) - offset;
    // TODO(arbenson): handle EOVERFLOW if too big.
    break;
  default:
    errno = EINVAL;
    return -1;
  }
  // Must not seek beyond the front of the file.
  if (next < 0) {
    errno = EINVAL;
    return -1;
  }
  // Go to the new offset.
  handle->offset = next;
  return handle->offset;
}

int KernelProxy::chmod(const std::string& path, mode_t mode) {
  if (path.empty()) {
    errno = ENOENT;
    return -1;
  }

  Path p(path);
  if (path[0] != '/') {
    p = Path(cwd_.FormulatePath() + "/" + path);
  }

  struct stat buf;
  Mount *mount = mm_.GetNode(p.FormulatePath(), &buf);

  if (!mount) {
    errno = ENOENT;
    return -1;
  }
  return mount->Chmod(buf.st_ino, mode);
}

int KernelProxy::remove(const std::string& path) {
  if (path.empty()) {
    errno = ENOENT;
    return -1;
  }

  Path p(path);
  if (path[0] != '/') {
    p = Path(cwd_.FormulatePath() + "/" + path);
  }

  std::pair<Mount *, std::string> mp = mm_.GetMount(p.FormulatePath());
  if (!mp.first) {
    errno = ENOENT;
    return -1;
  }
  struct stat st;
  if (0 != mp.first->GetNode(mp.second, &st)) {
    errno = ENOENT;
    return -1;
  }
  if (S_ISDIR(st.st_mode)) {
    return mp.first->Rmdir(st.st_ino);
  }
  if (S_ISREG(st.st_mode)) {
    return mp.first->Unlink(mp.second);
  }
  // Only support regular files and directories now.
  errno = EINVAL;
  return -1;
}

int KernelProxy::unlink(const std::string& path) {
  if (path.empty()) {
    errno = ENOENT;
    return -1;
  }

  Path p(path);
  if (path[0] != '/') {
    p = Path(cwd_.FormulatePath() + "/" + path);
  }

  std::pair<Mount *, std::string> mp = mm_.GetMount(p.FormulatePath());
  if (!mp.first) {
    errno = ENOENT;
    return -1;
  }

  return mp.first->Unlink(mp.second);
}

int KernelProxy::umount(const std::string& path) {
  if (path.empty()) {
    errno = ENOENT;
    return -1;
  }

  SimpleAutoLock lock(&kp_lock_);

  Path p(path);
  if (path[0] != '/') {
    p = Path(cwd_.FormulatePath() + "/" + path);
  }

  return mm_.RemoveMount(path.c_str());
}

int KernelProxy::mount(const std::string& path, void *mount) {
  if (path.empty()) {
    errno = ENOENT;
    return -1;
  }

  SimpleAutoLock lock(&kp_lock_);

  Mount *m = reinterpret_cast<Mount *>(mount);

  Path p(path);
  if (path[0] != '/') {
    p = Path(cwd_.FormulatePath() + "/" + path);
  }

  return mm_.AddMount(m, path.c_str());
}

int KernelProxy::stat(const std::string& path, struct stat *buf) {
  if (path.empty()) {
    errno = ENOENT;
    return -1;
  }

  Path p(path);
  if (path[0] != '/') {
    p = Path(cwd_.FormulatePath() + "/" + path);
  }

  Mount *mount = mm_.GetNode(p.FormulatePath(), buf);
  if (!mount) {
    errno = ENOENT;
    return -1;
  }
  return 0;
}

int KernelProxy::access(const std::string& path, int amode) {
  if (path.empty()) {
    errno = ENOENT;
    return -1;
  }

  Path p(path);
  if (path[0] != '/') {
    p = Path(cwd_.FormulatePath() + "/" + path);
  }

  std::list<std::string> path_components = p.path();
  std::list<std::string>::iterator it;
  std::list<std::string> incremental_paths;

  // All components of the path are checked for access permissions.
  std::string curr_path = "/";
  incremental_paths.push_back(curr_path);

  // Formulate the path of each component.
  for (it = path_components.begin();
       it != path_components.end(); ++it) {
    curr_path += "/";
    curr_path += *it;
    incremental_paths.push_back(curr_path);
  }

  // Loop over each path component and
  // check access permissions.
  for (it = incremental_paths.begin();
       it != incremental_paths.end(); ++it) {
    curr_path = *it;
    // first call stat on the file
    struct stat buf;
    if (stat(curr_path, &buf) == -1) {
      return -1;  // stat should take care of errno
    }
    mode_t mode = buf.st_mode;

    // We know that the file exists at this point.
    // Thus, we don't have to check F_OK.
    if (((amode & R_OK) && !(mode & R_OK)) ||
        ((amode & W_OK) && !(mode & W_OK)) ||
        ((amode & X_OK) && !(mode & X_OK))) {
        errno = EACCES;
        return -1;
    }
  }
  // By now we have checked access permissions for
  // each component of the path.
  return 0;
}

KernelProxy::FileHandle* KernelProxy::GetFileHandle(int fd) {
  SimpleAutoLock lock(&kp_lock_);
  FileDescriptor *file = fds_.At(fd);
  if (!file) {
    return NULL;
  }
  return open_files_.At(file->handle);
}

int KernelProxy::mkdir(const std::string& path, mode_t mode) {
  if (path.empty()) {
    return -1;
  }

  Path p(path);
  if (path[0] != '/') {
    p = Path(cwd_.FormulatePath() + "/" + path);
  }

  std::pair<Mount *, std::string> m_and_p =
    mm_.GetMount(p.FormulatePath());
  if (!(m_and_p.first)) {
    errno = ENOTDIR;
    return -1;
  }
  return m_and_p.first->Mkdir(m_and_p.second, mode, NULL);
}

int KernelProxy::rmdir(const std::string& path) {
  if (path.empty()) {
    errno = ENOENT;
    return -1;
  }

  Path p(path);
  if (path[0] != '/') {
    p = Path(cwd_.FormulatePath() + "/" + path);
  }

  struct stat buf;
  std::string abs_path = p.FormulatePath();
  Mount *mount = mm_.GetNode(abs_path, &buf);
  if (!mount) {
    errno = ENOENT;
    return -1;
  }

  // Check if a mount is mounted on abs_path or on a subdirectory of abs_path
  if (mm_.InMountRootPath(abs_path)) {
    errno = EBUSY;
    return -1;
  }

  return mount->Rmdir(buf.st_ino);
}

int KernelProxy::socket(int domain, int type, int protocol) {
  SimpleAutoLock lock(&kp_lock_);
  int handle_slot = open_files_.Alloc();
  int fd = fds_.Alloc();
  FileDescriptor* file = fds_.At(fd);
  file->handle = handle_slot;
  FileHandle* handle = open_files_.At(handle_slot);
  // this means it is a socket (not a mount handle) and it's implementation
  // determined by handle->stream type is defined later
  handle->mount = NULL;
  handle->stream = NULL;
  handle->use_count = 1;
  return fd;
}

int KernelProxy::accept(int sockfd, struct sockaddr *addr,
    socklen_t* addrlen) {
  if (GetFileHandle(sockfd) == 0)
    return EBADF;
  Socket* ret = socket_subsystem_->accept(GetFileHandle(sockfd)->stream,
    addr, addrlen);
  if (ret)
    return AddSocket(ret);
  else
    return -1;
}

int KernelProxy::bind(int sockfd, const struct sockaddr *addr,
                      socklen_t addrlen) {
  if (GetFileHandle(sockfd) == 0)
    return EBADF;
  struct sockaddr_in* in_addr = (struct sockaddr_in*)addr;
  return socket_subsystem_->bind(&(GetFileHandle(sockfd)->stream),
      addr, addrlen);
}

int KernelProxy::listen(int sockfd, int backlog) {
  if (GetFileHandle(sockfd) == 0)
    return EBADF;
  return socket_subsystem_->listen(GetFileHandle(sockfd)->stream, backlog);
}

int KernelProxy::connect(int sockfd, const struct sockaddr *addr,
                         socklen_t addrlen) {
  if (GetFileHandle(sockfd) == 0)
    return EBADF;
  struct sockaddr_in* in_addr = (struct sockaddr_in*)addr;
  return socket_subsystem_->connect(&(GetFileHandle(sockfd)->stream),
      addr, addrlen);
}

int KernelProxy::send(int sockfd, const void *buf, size_t len, int flags) {
  if (GetFileHandle(sockfd) == 0)
    return EBADF;
  size_t nwr;
  socket_subsystem_->write(GetFileHandle(sockfd)->stream, (const char*)buf,
    len, &nwr);
  return nwr;
}

int KernelProxy::sendmsg(int sockfd, const struct msghdr *msg, int flags) {
  errno = ENOSYS;
  fprintf(stderr, "sendmsg has not been implemented!\n");
  return -1;
}

int KernelProxy::sendto(int sockfd, const void *buf, size_t len, int flags,
           const struct sockaddr *dest_addr, socklen_t addrlen) {
  errno = ENOSYS;
  fprintf(stderr, "sendto has not been implemented!\n");
  return -1;
}

int KernelProxy::recv(int sockfd, void *buf, size_t len, int flags) {
  if (GetFileHandle(sockfd) == 0)
    return EBADF;
  size_t nread;
  socket_subsystem_->read(GetFileHandle(sockfd)->stream,
    reinterpret_cast<char*>(buf), len, &nread);
  return nread;
}

int KernelProxy::recvmsg(int sockfd, struct msghdr *msg, int flags) {
  errno = ENOSYS;
  fprintf(stderr, "recvmsg has not been implemented!\n");
  return -1;
}

int KernelProxy::recvfrom(int sockfd, void *buf, size_t len, int flags,
             struct sockaddr *dest_addr, socklen_t* addrlen) {
  errno = ENOSYS;
  fprintf(stderr, "recvfrom has not been implemented!\n");
  return -1;
}

#ifndef TIMEVAL_TO_TIMESPEC
/* Macros for converting between `struct timeval' and `struct timespec'.  */
# define TIMEVAL_TO_TIMESPEC(tv, ts) {                                  \
        (ts)->tv_sec = (tv)->tv_sec;                                    \
        (ts)->tv_nsec = (tv)->tv_usec * 1000;                           \
}
# define TIMESPEC_TO_TIMEVAL(tv, ts) {                                  \
        (tv)->tv_sec = (ts)->tv_sec;                                    \
        (tv)->tv_usec = (ts)->tv_nsec / 1000;                           \
}
#endif

int KernelProxy::select(int nfds, fd_set *readfds, fd_set *writefds,
           fd_set* exceptfds, const struct timeval *timeout) {
  timespec ts_abs;
  if (timeout) {
    timespec ts;
    TIMEVAL_TO_TIMESPEC(timeout, &ts);
    timeval tv_now;
    gettimeofday(&tv_now, NULL);
    int64_t current_time_us =
        tv_now.tv_sec * kMicrosecondsPerSecond + tv_now.tv_usec;
    int64_t wakeup_time_us =
        current_time_us +
        timeout->tv_sec * kMicrosecondsPerSecond + timeout->tv_usec;
     ts_abs.tv_sec = wakeup_time_us / kMicrosecondsPerSecond;
     ts_abs.tv_nsec =
        (wakeup_time_us - ts_abs.tv_sec * kMicrosecondsPerSecond) *
        kNanosecondsPerMicrosecond;
  }

  while (!(IsReady(nfds, readfds, &Socket::is_read_ready, false) ||
          IsReady(nfds, writefds, &Socket::is_write_ready, false) ||
          IsReady(nfds, exceptfds, &Socket::is_exception, false))) {
    SimpleAutoLock lock(select_mutex().get());
    if (timeout) {
      if (!timeout->tv_sec && !timeout->tv_usec)
        break;

      if (select_cond().timedwait(select_mutex(), &ts_abs)) {
        if (errno == ETIMEDOUT)
          break;
        else
          return -1;
      }
    } else {
      select_cond().wait(select_mutex());
    }
  }

  int nread = IsReady(nfds, readfds, &Socket::is_read_ready, true);
  int nwrite = IsReady(nfds, writefds, &Socket::is_write_ready, true);
  int nexcpt = IsReady(nfds, exceptfds, &Socket::is_exception, true);
  if (nread < 0 || nwrite < 0 || nexcpt < 0) {
    errno = EBADF;
    return -1;
  }
  return nread + nwrite + nexcpt;
}

int KernelProxy::pselect(int nfds, fd_set *readfds, fd_set *writefds,
            fd_set* exceptfds, const struct timeval *timeout, void* sigmask) {
  errno = ENOSYS;
  fprintf(stderr, "pselect has not been implemented!\n");
  return -1;
}

int KernelProxy::getpeername(int sockfd, struct sockaddr *addr,
                             socklen_t* addrlen) {
  errno = ENOSYS;
  fprintf(stderr, "getpeername has not been implemented!\n");
  return -1;
}

int KernelProxy::getsockname(int sockfd, struct sockaddr *addr,
                             socklen_t* addrlen) {
  errno = ENOSYS;
  fprintf(stderr, "getsockname has not been implemented!\n");
  return -1;
}

int KernelProxy::getsockopt(int sockfd, int level, int optname, void *optval,
               socklen_t* optlen) {
  errno = ENOSYS;
  fprintf(stderr, "getsockopt has not been implemented!\n");
  return -1;
}

int KernelProxy::setsockopt(int sockfd, int level, int optname,
            const void *optval, socklen_t optlen) {
  errno = ENOSYS;
  fprintf(stderr, "setsockopt has not been implemented!\n");
  return -1;
}

int KernelProxy::shutdown(int sockfd, int how) {
  FileHandle* fh = GetFileHandle(sockfd);
  if (fh == 0)
    return EBADF;
  return socket_subsystem_->shutdown(fh->stream, how);
}

int KernelProxy::socketpair(int domain, int type, int protocol, int sv[2]) {
  errno = ENOSYS;
  fprintf(stderr, "socketpair has not been implemented!\n");
  return -1;
}

