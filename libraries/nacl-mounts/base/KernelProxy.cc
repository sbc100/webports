/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <assert.h>
#include <list>
#include <utility>
#include "../console/ConsoleMount.h"
#include "KernelProxy.h"
#include "MountManager.h"

static pthread_once_t kp_once_ = PTHREAD_ONCE_INIT;
KernelProxy *KernelProxy::kp_instance_;

#ifndef MAXPATHLEN
#define MAXPATHLEN 256
#endif

KernelProxy::KernelProxy() {
  if (pthread_mutex_init(&kp_lock_, NULL)) assert(0);
  cwd_ = Path("/");
  mm_.Init();

  // Setup file descriptors 0, 1, and 2 for STDIN, STDOUT, and STDERR
  int ret = mkdir("/dev", 0777);
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
  FileDescriptor *file = fds_.At(fd);
  file->handle = handle_slot;
  FileHandle *handle = open_files_.At(handle_slot);

  // init should be safe because we have the kernel proxy lock
  if (pthread_mutex_init(&handle->lock, NULL)) assert(0);

  handle->mount = mount;
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

  FileDescriptor *file = fds_.At(fd);
  if (file == NULL) {
    errno = EBADF;
    return -1;
  }
  int h = file->handle;
  fds_.Free(fd);
  FileHandle *handle = open_files_.At(h);
  if (handle == NULL) {
    errno = EBADF;
    return -1;
  }
  handle->use_count--;
  ino_t node = handle->node;
  Mount *mount = handle->mount;
  if (handle->use_count <= 0) {
    open_files_.Free(h);
    mount->Unref(node);
  }
  mount->Unref();
  return 0;
}

ssize_t KernelProxy::read(int fd, void *buf, size_t count) {
  FileHandle *handle;
  // check if fd is valid and handle exists
  if (!(handle = GetFileHandle(fd))) {
    errno = EBADF;
    return -1;
  }

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
}

ssize_t KernelProxy::write(int fd, const void *buf, size_t count) {
  FileHandle *handle;

  // check if fd is valid and handle exists
  if (!(handle = GetFileHandle(fd))) {
    errno = EBADF;
    return -1;
  }

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
}

int KernelProxy::fstat(int fd, struct stat *buf) {
  FileHandle *handle;

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
  FileHandle *handle;

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
  FileHandle *handle;

  if (!(handle = GetFileHandle(fd))) {
    errno = EBADF;
    return -1;
  }
  SimpleAutoLock(&handle->lock);
  return handle->mount->Fsync(handle->node);
}

int KernelProxy::isatty(int fd) {
  FileHandle *handle;

  if (!(handle = GetFileHandle(fd))) {
    errno = EBADF;
    return 0;
  }
  SimpleAutoLock(&handle->lock);
  return handle->mount->Isatty(handle->node);
}

int KernelProxy::dup(int oldfd) {
  SimpleAutoLock lock(&kp_lock_);

  FileDescriptor *oldfile = fds_.At(oldfd);
  if (oldfile == NULL) {
    errno = EBADF;
    return -1;
  }
  int newfd = fds_.Alloc();
  FileDescriptor *newfile = fds_.At(newfd);
  int h = oldfile->handle;
  newfile->handle = h;
  FileHandle *handle = open_files_.At(h);
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
  FileHandle *handle;
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

KernelProxy::FileHandle *KernelProxy::GetFileHandle(int fd) {
  SimpleAutoLock lock(&kp_lock_);
  FileDescriptor *file = fds_.At(fd);
  if (!file) {
    return NULL;
  }
  return open_files_.At(file->handle);
}
