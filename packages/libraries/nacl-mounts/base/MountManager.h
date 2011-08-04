/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_SCRIPTS_NACL_MOUNTS_BASE_MOUNTMANAGER_H_
#define PACKAGES_SCRIPTS_NACL_MOUNTS_BASE_MOUNTMANAGER_H_

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <map>
#include <string>
#include <utility>
#include <vector>
#include "BaseMount.h"
#include "../util/Path.h"
#include "../util/SimpleAutoLock.h"

class Mount;

// MountManager serves as an indirection layer for POSIX calls.  Different
// mount types can be added to the mount manager so that different system call
// implementations can be used at different locations in the file system.
// This allows for the use of different backend storage devices to be used
// by one native client executable.
class MountManager {
 public:
  MountManager();
  ~MountManager();
  // Obtain the singleton instance of the mount manager.  If no instance
  // has been instantiated, one will be instantiated and returned.
  static MountManager *MMInstance();

  void Init(void);

  // Add a new mount type in the file system.  Starting at path, sys calls
  // are determined by the implementation in mount m.  The mount manager
  // is responsible for deleting all mounts that are added.
  // Return value is:
  // 0 on success
  // -1 on failure due to another mount rooted at path
  // -2 on failure due to a bad (NULL) mount provided
  // -3 on failure due to a bad path provided
  int AddMount(Mount *m, const char *path);

  // Remove a mount type from the file system.  RemoveMount() will try to
  // remove a mount rooted at path.  If there is no mount rooted at path,
  // then -1 is returned.  On success, 0 is returned.
  // Removing a mount is NOT thread safe.
  int RemoveMount(const char *path);

  // Given an absolute path, GetMount() will return the mount at that location.
  std::pair<Mount *, std::string> GetMount(const std::string& path);

  // Remove all mounts that have been added.  The destructors of these
  // mounts will be called.
  void ClearMounts(void);

  // Get the Mount corresponding to the node.  GetNode() also fills the stat
  // buffer with information about the node.
  Mount *GetNode(const std::string& path, struct stat *buf);

 private:
  std::map<std::string, Mount*> mount_map_;
  Mount *cwd_mount_;
  pthread_mutex_t mm_lock_;
};

#endif  // PACKAGES_SCRIPTS_NACL_MOUNTS_BASE_MOUNTMANAGER_H_
