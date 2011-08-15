/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <assert.h>
#include <errno.h>
#include <ppapi/c/pp_file_info.h>
#include <ppapi/cpp/file_io.h>
#include <ppapi/cpp/file_ref.h>
#include <stdio.h>
#include "../base/MainThreadRunner.h"
#include "../util/Path.h"
#include "../util/SimpleAutoLock.h"
#include "PepperFileIOJob.h"
#include "PepperMount.h"
#include "PepperNode.h"

PepperMount::PepperMount(MainThreadRunner *runner, pp::FileSystem *fs,
                         int64_t exp_size) {
  if (pthread_mutex_init(&pp_lock_, NULL)) assert(0);
  runner_ = runner;
  fs_ = fs;
  PepperFileIOJob *job = new PepperFileIOJob;
  job->set_fs(fs);
  job->set_op(OPEN_FILE_SYSTEM);
  job->set_exp_size(exp_size);
  runner_->RunJob(job);
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

  node->file_io()->Close();
  slots_.Free(node->slot());
}

int PepperMount::Creat(const std::string& path, mode_t mode,
                       struct stat *buf) {
  SimpleAutoLock lock(&pp_lock_);
  Path p("/" + path);
  std::string abs_path = p.FormulatePath();
  pp::FileRef *ref = new pp::FileRef(*fs_, path.c_str());
  pp::FileIO *io = new pp::FileIO;

  // setup the node
  int slot = slots_.Alloc();
  PepperNode *node = slots_.At(slot);

  node->set_file_io(io);
  node->set_path(abs_path);

  // setup the job
  PepperFileIOJob *job = new PepperFileIOJob;
  job->set_op(OPEN_FILE);
  job->set_file_ref(ref);
  job->set_file_io(node->file_io());
  job->set_flags(mode);
  int ret = runner_->RunJob(job);
  if (ret <= 0) {
    errno = EIO;
    return -1;
  }

  path_map_[abs_path] = slot;
  return Stat(slot, buf);
}

int PepperMount::GetNode(const std::string& path, struct stat *buf) {
  SimpleAutoLock lock(&pp_lock_);

  Path p("/" + path);
  std::string abs_path = p.FormulatePath();

  std::map<std::string, int>::iterator it = path_map_.find(abs_path);
  if (it != path_map_.end()) {
    assert(buf);
    return Stat(it->second, buf);
  }
  return -1;
}

int PepperMount::Stat(ino_t slot, struct stat *buf) {
  PepperNode *node = slots_.At(slot);
  if (node == NULL) {
    errno = ENOENT;
    return -1;
  }

  PepperFileIOJob *job = new PepperFileIOJob;
  job->set_op(QUERY_FILE);
  job->set_file_io(node->file_io());
  struct PP_FileInfo *q_buf =
    (struct PP_FileInfo *)malloc(sizeof(struct PP_FileInfo));
  job->set_query_buf(q_buf);
  int ret = runner_->RunJob(job);
  if (ret < 0) {
    errno = EIO;
    return -1;
  }

  memset(buf, 0, sizeof(struct stat));
  buf->st_ino = (ino_t)slot;
  if (q_buf->type == PP_FILETYPE_DIRECTORY) {
    node->set_is_dir(true);
    buf->st_mode = S_IFDIR | 0777;
  } else {
    buf->st_mode = S_IFREG | 0777;
    buf->st_size = q_buf->size;
  }
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
