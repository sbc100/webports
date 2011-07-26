/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_SCRIPTS_NACL_MOUNTS_APPENGINE_APPENGINEMOUNT_H_
#define PACKAGES_SCRIPTS_NACL_MOUNTS_APPENGINE_APPENGINEMOUNT_H_

#include <dirent.h>
#include <pthread.h>
#include <list>
#include <map>
#include <string>
#include "../base/BaseMount.h"
#include "../util/Path.h"
#include "../util/SlotAllocator.h"
#include "AppEngineNode.h"

class MainThreadRunner;

// AppEngineMount is a read/write mount to a Google AppEngine server.  Requests
// are made as POST requests to the server.  See Creat(), Getdents(), Fsync(),
// and Unlink() for details on how these requests are made.  A sample backend
// python server script can be found in the /nacl-mounts/AppEngine/naclmounts.
// Data is read from the AppEngineServer on node creation and then is written
// back to the server when all file descriptors to a node have been closed.
// Between opening and closing of an AppEngine file, data is manipulated
// locally in memory.
class AppEngineMount: public BaseMount {
 public:
  // runner is used to execute jobs on the main thread
  // All url requests to the AppEngine server are prepended with base_url_.
  // The base url should be relative to the AppEngine URL without a trailing
  // slash.  For example, relative to http://your-app.appspot.com
  AppEngineMount(MainThreadRunner *runner, const std::string& base_url);
  virtual ~AppEngineMount() {}

  void Ref(ino_t node);
  void Unref(ino_t node);
  int GetNode(const std::string& path, struct stat *st);

  // Creat() makes a request to base_url/read with the filename corresponding
  // to the node at path.
  int Creat(const std::string& path, mode_t mode, struct stat *st);
  int Stat(ino_t node, struct stat *buf);

  // Getdents() makes a request to base_url/list with the filename
  // corresponding to the node.
  int Getdents(ino_t node, off_t offset, struct dirent *dirp,
               unsigned int count);

  // Fsync() makes a request to base_url/write with the filename and data
  // corresponding to the node.
  int Fsync(ino_t node);

  // Unlink() makes a request to base_url/remove with the filename
  // corresponding to the node at path.
  int Unlink(const std::string& path);

  // Read() reads data from the local representation of the node, not
  // the server.
  ssize_t Read(ino_t node, off_t offset, void *buf, size_t count);

  // Write() writes buf to the local representation of the node, not
  // the server
  ssize_t Write(ino_t node, off_t offset, const void *buf, size_t count);

  // Mkdir() creates a local representation of a directory but adds nothing
  // to the server.
  virtual int Mkdir(const std::string& path, mode_t mode, struct stat *st);

  std::string base_url(void) { return base_url_; }

 private:
  SlotAllocator<AppEngineNode> slots_;
  std::string base_url_;
  std::map<std::string, int> path_map_;
  MainThreadRunner *runner_;
  pthread_mutex_t ae_lock_;

  bool IsDir(ino_t slot);
  int RemoteRead(const std::string& path, std::vector<char> *data);
  int CreateNode(const std::string& path, std::vector<char> *data);

  DISALLOW_COPY_AND_ASSIGN(AppEngineMount);
};

#endif  // PACKAGES_SCRIPTS_NACL_MOUNTS_APPENGINE_APPENGINEMOUNT_H_
