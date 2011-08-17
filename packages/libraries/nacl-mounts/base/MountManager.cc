/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <stdio.h>
#include "../console/ConsoleMount.h"
#include "../memory/MemMount.h"
#include "MountManager.h"

MountManager::MountManager() {
  if (pthread_mutex_init(&mm_lock_, NULL)) assert(0);
}

MountManager::~MountManager() {
  if (pthread_mutex_destroy(&mm_lock_)) assert(0);
  ClearMounts();
}

void MountManager::Init() {
  MemMount *default_mount = new MemMount();
  int ret = AddMount(default_mount, "/");
  assert(ret == 0);
  cwd_mount_ = default_mount;
}

int MountManager::AddMount(Mount *m, const char *path) {
  // check for null mount
  if (!m) return -2;
  // check for NULL path
  if (!path) return -3;
  std::string p(path);
  // check for empty path
  if (p.empty()) return -3;
  // check for access to the parent directory
  if (p != "/") {
    struct stat buf;
    memset(&buf, 0, sizeof(struct stat));
    Path parent(p + "/..");
    GetNode(parent.FormulatePath(), &buf);
    if (buf.st_ino == 0) return -4;
  }

  SimpleAutoLock lock(&mm_lock_);

  std::map<std::string, Mount *>::iterator it = mount_map_.find(p);
  if (it != mount_map_.end() && it->second != NULL) {
    // a mount already exists at that path
    return -1;
  }
  mount_map_[p] = m;
  return 0;
}

int MountManager::RemoveMount(const char *path) {
  SimpleAutoLock lock(&mm_lock_);

  std::string p(path);
  std::map<std::string, Mount *>::iterator it;
  it = mount_map_.find(p);
  if (it == mount_map_.end()) {
    errno = ENOENT;
    return -1;
  } else {
    if (it->second->ref_count() > 0) {
      errno = EBUSY;
      return -1;
    }
    if (cwd_mount_ == it->second) {
      cwd_mount_ = NULL;
    }
    // erase() calls the destructor
    mount_map_.erase(it);
    return 0;
  }
}

void MountManager::ClearMounts(void) {
  SimpleAutoLock lock(&mm_lock_);

  std::map<std::string, Mount *>::iterator it;
  for (it = mount_map_.begin(); it != mount_map_.end(); ++it) {
    if (it->second != NULL && it->second->ref_count() <= 0) {
      delete it->second;
      it->second = NULL;
    }
  }
  cwd_mount_ = NULL;
}

Mount *MountManager::GetNode(const std::string& path,
                             struct stat *buf) {
  // check if path is of length zero
  if (path.length() == 0) {
    return NULL;
  }

  std::pair<Mount *, std::string> m_and_p = GetMount(path);

  // Wait until after GetMount() to acquire the lock
  SimpleAutoLock lock(&mm_lock_);

  if ((m_and_p.second).length() == 0) {
    return NULL;
  } else {
    if (!m_and_p.first) {
      return NULL;
    }
    if (0 != m_and_p.first->GetNode(m_and_p.second, buf)) {
      return NULL;
    }
    return m_and_p.first;
  }
}

std::pair<Mount *, std::string> MountManager::GetMount(
    const std::string& path) {
  SimpleAutoLock lock(&mm_lock_);

  std::pair<Mount *, std::string> ret;
  std::map<std::string, Mount *>::iterator it;
  std::string curr_best = "";
  ret.first = NULL;
  ret.second = path;

  if (path.length() == 0) {
    return ret;
  }

  // Find the longest path in the map that matches
  // the start of path
  for (it = mount_map_.begin(); it != mount_map_.end(); ++it) {
    if (path.find(it->first) == 0) {
      if (it->first.length() > curr_best.length()) {
        curr_best = it->first;
      }
    }
  }

  if (curr_best.length() == 0) {
    return ret;
  }

  ret.first = mount_map_[curr_best];
  // if the path matches exactly, returned path is empty string
  if (curr_best.compare(path) == 0) {
    ret.second = "/";
  } else {
    ret.second = path.substr(curr_best.length());
  }
  return ret;
}

Mount *MountManager::InMountRootPath(const std::string& path) {
  if (path.length() == 0) {
    return NULL;
  }

  SimpleAutoLock lock(&mm_lock_);
  std::map<std::string, Mount *>::iterator it;
  for (it = mount_map_.begin(); it != mount_map_.end(); ++it) {
    if (it->first.find(path) == 0) {
      return it->second;
    }
  }
  return NULL;
}
