/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <assert.h>
#include <errno.h>
#include <ppapi/c/pp_file_info.h>
#include <ppapi/c/ppb_file_io.h>
#include <ppapi/cpp/file_io.h>
#include <ppapi/cpp/file_ref.h>
#include <stdio.h>
#include "../base/MainThreadRunner.h"
#include "../util/Path.h"
#include "../util/SimpleAutoLock.h"
#include "../util/DebugPrint.h"
#include "PepperFileIOJob.h"
#include "PepperMount.h"
#include "PepperNode.h"

PepperMount::PepperMount(MainThreadRunner *runner, pp::FileSystem *fs,
                         int64_t exp_size) {
  if (pthread_mutex_init(&pp_lock_, NULL)) assert(0);
  runner_ = runner;
  fs_ = fs;
  path_prefix_ = "/";

  PepperFileIOJob *job = new PepperFileIOJob;
  job->set_fs(fs);
  job->set_op(OPEN_FILE_SYSTEM);
  job->set_exp_size(exp_size);
  runner_->RunJob(job);

  int slot = slots_.Alloc();
  PepperNode *node = slots_.At(slot);
  node->set_slot(slot);
  node->set_path("/");
  node->set_is_dir(true);
}

int PepperMount::GetSlot(const std::string& path) {
  std::string p = Path(path).FormulatePath();
  PepperNode *node = NULL;
  for (int slot = 0; node = slots_.At(slot); ++slot) {
    if (node->path() == p) {
      return slot;
    }
  }
  return -1;
}

void PepperMount::Ref(ino_t slot) {
  SimpleAutoLock lock(&pp_lock_);
  PepperNode *node = slots_.At(slot);
  if (node == NULL) {
    return;
  }
  node->IncrementUseCount();
}

void PepperMount::Unref(ino_t slot) {
  SimpleAutoLock lock(&pp_lock_);
  PepperNode *node = slots_.At(slot);
  if (node == NULL) {
    return;
  }
  if (node->is_dir()) {
    return;
  }
  node->DecrementUseCount();
  if (node->use_count() > 0) {
    return;
  }

  PepperFileIOJob *job = new PepperFileIOJob;
  job->set_op(CLOSE_FILE);
  job->set_fs(fs_);
  job->set_file_io(node->file_io());
  int ret = runner_->RunJob(job);
  assert(ret == PP_OK); // Close() never fails

  slots_.Free(node->slot());
}

int PepperMount::AllocateSlot(const std::string& abs_path, bool create) {
  std::string fs_path = Path(path_prefix_).AppendPath(abs_path).FormulatePath();

  // setup the job
  pp::FileIO* io;
  PepperFileIOJob *job = new PepperFileIOJob;
  job->set_op(OPEN_FILE);
  job->set_fs(fs_);
  job->set_path(fs_path);
  job->set_file_io_p(&io);
  int flags = PP_FILEOPENFLAG_READ | PP_FILEOPENFLAG_WRITE;
  if (create)
    flags |= PP_FILEOPENFLAG_CREATE;
  job->set_flags(flags);
  int ret = runner_->RunJob(job);
  if (ret < 0) {
    errno = EIO;
    return -1;
  }

  // setup the node
  int slot = slots_.Alloc();
  PepperNode *node = slots_.At(slot);
  node->set_slot(slot);
  node->set_file_io(io);
  node->set_path(abs_path);

  return slot;
}

int PepperMount::Creat(const std::string& path, mode_t mode,
                       struct stat *buf) {
  SimpleAutoLock lock(&pp_lock_);

  Path p("/" + path);
  std::string abs_path = p.FormulatePath();

  int slot = AllocateSlot(abs_path, true);
  if (slot < 0)
    return slot;

  return Stat(slot, buf);
}

int PepperMount::GetNode(const std::string& path, struct stat *buf) {
  SimpleAutoLock lock(&pp_lock_);

  Path p("/" + path);
  std::string abs_path = p.FormulatePath();

  int slot = GetSlot(abs_path);
  if (slot < 0) {
    slot = AllocateSlot(abs_path, false);

    if (slot < 0)
      return slot;
  }

  return Stat(slot, buf);
}

int PepperMount::Stat(ino_t slot, struct stat *buf) {

  PepperNode *node = slots_.At(slot);
  if (node == NULL) {
    errno = ENOENT;
    return -1;
  }

  if (node->is_dir()) {
    memset(buf, 0, sizeof(struct stat));
    buf->st_ino = (ino_t)slot;
    buf->st_mode = S_IFDIR | 0777;
    buf->st_size = 0;
    buf->st_uid = 1001;
    buf->st_gid = 1002;
    buf->st_blksize = 1024;
    return 0;
  }

  PepperFileIOJob *job = new PepperFileIOJob;
  job->set_op(QUERY_FILE);
  job->set_file_io(node->file_io());
  struct PP_FileInfo *q_buf =
    (struct PP_FileInfo *)malloc(sizeof(struct PP_FileInfo));
  job->set_query_buf(q_buf);
  int ret = runner_->RunJob(job);
  if (ret < 0) {
    dbgprintf("stat error %d\n", ret);
    errno = EIO;
    return -1;
  }

  memset(buf, 0, sizeof(struct stat));
  buf->st_ino = (ino_t)slot;
  buf->st_mode = S_IFREG | 0777;
  buf->st_size = q_buf->size;
  buf->st_uid = 1001;
  buf->st_gid = 1002;
  buf->st_blksize = 1024;
  return 0;
}

ssize_t PepperMount::Read(ino_t slot, off_t offset, void *buf,
                          size_t count) {
  SimpleAutoLock lock(&pp_lock_);
  PepperNode *node = slots_.At(slot);
  if (node == NULL) {
    errno = ENOENT;
    return -1;
  }

  PepperFileIOJob *job = new PepperFileIOJob;
  job->set_op(READ_FILE);
  job->set_file_io(node->file_io());
  job->set_offset(offset);
  job->set_read_buf(static_cast<char *>(buf));
  job->set_nbytes(count);
  int ret = runner_->RunJob(job);
  if (ret < 0) {
    errno = EIO;
    return -1;
  }
  // if ret is 0, we have reached end of file
  return ret;
}

ssize_t PepperMount::Write(ino_t slot, off_t offset, const void *buf,
                           size_t count) {
  SimpleAutoLock lock(&pp_lock_);

  PepperNode *node = slots_.At(slot);
  if (node == NULL) {
    errno = ENOENT;
    return -1;
  }

  PepperFileIOJob *job = new PepperFileIOJob;
  job->set_op(WRITE_FILE);
  job->set_file_io(node->file_io());
  job->set_offset(offset);
  job->set_write_buf(static_cast<const char *>(buf));
  job->set_nbytes(count);
  int ret = runner_->RunJob(job);
  if (ret < 0) {
    errno = EIO;
    return -1;
  }
  // if ret is 0, we have reached end of file
  return ret;
}

int PepperMount::Mkdir(const std::string& path, mode_t mode,
    struct stat *st) {
  SimpleAutoLock lock(&pp_lock_);

  Path p("/" + path);
  std::string abs_path = p.FormulatePath();
  std::string fs_path = Path(path_prefix_).AppendPath(abs_path).FormulatePath();

  PepperFileIOJob *job = new PepperFileIOJob;
  job->set_op(MAKE_DIR);
  job->set_fs(fs_);
  job->set_path(fs_path);
  int ret = runner_->RunJob(job);
  if (ret < 0) {
    dbgprintf("mkdir failed %d\n", ret);
    errno = EIO;
    return -1;
  }

  int slot = slots_.Alloc();
  PepperNode *node = slots_.At(slot);
  node->set_slot(slot);
  node->set_path(abs_path);
  node->set_is_dir(true);

  return 0;
}

int PepperMount::Getdents(ino_t slot, off_t offset,
                        struct dirent *dir, unsigned int count) {
  if (!directory_reader_) {
    errno = ENOSYS;
    return -1;
  }

  PepperNode* node = slots_.At(slot);
  if (node == NULL) {
    errno = ENOENT;
    return -1;
  }

  if (!node->is_dir()) {
    errno = ENOTDIR;
    return -1;
  }

  std::string fs_path =
    Path(path_prefix_).AppendPath(node->path()).FormulatePath();

  std::set<std::string> entries;
  PepperFileIOJob *job = new PepperFileIOJob;
  job->set_op(READ_DIR);
  job->set_path(fs_path);
  job->set_dir_entries(&entries);
  job->set_directory_reader(directory_reader_);
  int ret = runner_->RunJob(job);
  if (ret < 0) {
    dbgprintf("readdir failed %d\n", ret);
    errno = EIO;
    return -1;
  }

  // Now that we have the directory names, we can formulate the dirent structs.
  std::set<std::string>::iterator it = entries.begin();
  // Skip to the offset
  while (offset > 0 && it != entries.end()) {
    --offset;
    ++it;
  }

  int bytes_read = 0;
  for (; it != entries.end() &&
       bytes_read + sizeof(struct dirent) <= count; ++it) {
    memset(dir, 0, sizeof(struct dirent));
    // We want d_ino to be non-zero because readdir()
    // will return null if d_ino is zero.
    dir->d_ino = 0x60061E;
    dir->d_off = sizeof(struct dirent);
    dir->d_reclen = sizeof(struct dirent);
    strncpy(dir->d_name, it->c_str(), sizeof(dir->d_name));
    ++dir;
    bytes_read += sizeof(struct dirent);
  }
  return bytes_read;
}
