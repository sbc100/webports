/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2MOUNT_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2MOUNT_H_

#include <dirent.h>
#include <set>
#include <string>
#include "../base/BaseMount.h"
#include "../base/MainThreadRunner.h"
#include "../base/UrlLoaderJob.h"
#include "../util/macros.h"
#include "../util/Path.h"
#include "../util/SlotAllocator.h"
#include "HTTP2Node.h"
#include "HTTP2ProgressHandler.h"

#include <ppapi/cpp/file_system.h>

class MainThreadRunner;

class HTTP2Mount: public BaseMount {
 public:
  // runner is used to execute jobs on the main thread
  // base_url_ is the HTTP server to which the HTTP2Mount will make requests.
  HTTP2Mount(MainThreadRunner *runner, std::string base_url);
  virtual ~HTTP2Mount() {}

  void SetLocalCache(pp::FileSystem *fs, int64_t fs_expected_size,
      std::string base_path);

  void SetProgressHandler(HTTP2ProgressHandler* handler) {
    progress_handler_ = handler;
  }

  /* int Creat(const std::string& path, mode_t mode, struct stat* st); */
  int GetNode(const std::string& path, struct stat* st);

  int Stat(ino_t node, struct stat *buf);
  int Getdents(ino_t node, off_t offset, struct dirent *dirp,
               unsigned int count);

  virtual ssize_t Read(ino_t node, off_t offset, void *buf, size_t count);

  // Add directory to the list of directories that the HTTP2Mount knows.
  void AddDir(const std::string& path);

  // Add file to the list of files that the HTTP2Mount knows. AddFile() should
  // be called for each file that will be accessed by the HTTP2Mount.
  void AddFile(const std::string& path, size_t size);

  // Set or clear "in-memory" flag of the file. In-memory files are kept
  // entirely in memory from the moment they are opened.
  void SetInMemory(const std::string& path, bool in_memory);

  // Specify that all reads of the file should be redirected to the file at pack
  // path with the given offset.
  void SetInPack(const std::string& path, const std::string& pack_path,
      off_t offset);

 private:

  int AddPath(const std::string& file, size_t size, bool is_dir);

  HTTP2Node *ToHTTP2Node(ino_t node) {
    return slots_.At(node);
  }

  int GetSlot(const std::string& path);

  SlotAllocator<HTTP2Node> slots_;
  MainThreadRunner *runner_;
  std::string base_url_;

  int doOpen(int slot);
  void OpenFileSystem();

  std::set<std::string> files_;

  pp::FileSystem* fs_;
  int64_t fs_expected_size_;
  std::string fs_base_path_;
  bool fs_opened_;

  HTTP2ProgressHandler* progress_handler_;

  pthread_mutex_t lock_;

  DISALLOW_COPY_AND_ASSIGN(HTTP2Mount);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_HTTP2_HTTP2MOUNT_H_
