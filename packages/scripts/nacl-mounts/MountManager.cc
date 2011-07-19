/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include "MountManager.h"

MountManager::MountManager() {
  Init();
}

MountManager::~MountManager() {
  ClearMounts();
}

void MountManager::Init() {
  if (pthread_mutex_init(&mm_lock_, NULL)) assert(0);
  // TODO(arbenson): make the default mount a memory mount.
  BaseMount *default_mount = new BaseMount();
  assert(default_mount);
  AddMount(default_mount, "/");
  cwd_mount_ = default_mount;
}

int MountManager::AddMount(Mount *m, const char *path) {
  SimpleAutoLock lock(&mm_lock_);

  if (!path) return -3;  // bad path
  if (!m) return -2;  // bad mount
  std::string p(path);
  if (p.empty()) return -3;  // bad path
  Mount *mount = mount_map_[path];
  if (mount) return -1;  // mount already exists
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
    if (it->second) {
      delete it->second;
      it->second = NULL;
    }
  }
  cwd_mount_ = NULL;
}

std::pair<Mount *, ino_t> MountManager::GetNode(const std::string& path) {
  std::pair<Mount *, std::string> m_and_p;
  std::pair<Mount *, ino_t> res;
  res.first = NULL;
  res.second = -1;

  // check if path is of length zero
  if (path.length() == 0) {
    return res;
  }

  m_and_p = GetMount(path);

  // Wait until after GetMount() to acquire the lock
  SimpleAutoLock lock(&mm_lock_);

  if ((m_and_p.second).length() == 0) {
    return res;
  } else {
    if (!m_and_p.first) {
      return res;
    }
    struct stat st;
    if (0 != m_and_p.first->GetNode(m_and_p.second, &st)) {
      return res;
    }
    res.first = m_and_p.first;
    res.second = st.st_ino;
    return res;
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
  for (it = mount_map_.begin();
       it != mount_map_.end() && path.length() != 0; ++it) {
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
