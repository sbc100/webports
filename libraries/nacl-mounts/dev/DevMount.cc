/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include "../dev/DevMount.h"
#ifdef __native_client__
#include <irt.h>
#endif
#include <sys/stat.h>
#include <cstring>
#include "../dev/NullDevice.h"
#ifdef __native_client__
#include "../dev/RandomDevice.h"
#endif

DevMount::DevMount() {
  max_inode = 2;
  // 1 and 2 are reserved for / and /fd, respectively
  NullDevice* dev_null = new NullDevice();
  if (dev_null == NULL) {
    throw 1;
  }
  Attach("/null", dev_null);
#ifdef __native_client__
  nacl_irt_random random;
  if (nacl_interface_query(NACL_IRT_RANDOM_v0_1, &random, sizeof(random))) {
    RandomDevice* dev_random = new RandomDevice(random.get_random_bytes);
    if (dev_random  == NULL) {
      throw 1;
    }
    Attach("/random", dev_random);
  }
#endif
}

void DevMount::Attach(std::string path, Device* device) {
  if (path_to_inode.find(path) == path_to_inode.end()) {
    int inode = ++this->max_inode;
    inode_to_path[inode] = path;
    inode_to_dev[inode]  = device;
    path_to_inode[path]  = inode;
  }
}

int DevMount::Mkdir(const std::string& path, mode_t mode,
                  struct stat *st) {
  if (path == "/fd" || path == "fd") {
    return Stat(2, st);
  }
  errno = ENOENT;
  return -1;
}

int DevMount::GetNode(const std::string& path, struct stat *buf) {
  if (path == "/") {
    return Stat(1, buf);
  };
  if (path == "/fd") {
    return Stat(2, buf);
  };
  if (path_to_inode.find(path) != path_to_inode.end()) {
    return Stat(path_to_inode[path], buf);
  } else {
    errno = ENOENT;
    return -1;
  }
}

int DevMount::Stat(ino_t node, struct stat *buf) {
  if ((inode_to_path.find(node) == inode_to_path.end()) && node > 2) {
    errno = ENOENT;
    return -1;
  }
  if (buf == NULL)
    return 0;
  memset(buf, 0, sizeof(struct stat));
  buf->st_ino = node;
  if (node > 2) {
    buf->st_mode = S_IFCHR | 0777;
  } else {
    buf->st_mode = S_IFDIR | 0777;
  };
  return 0;
}

int DevMount::Getdents(ino_t slot, off_t offset,
                       struct dirent *dir, unsigned int count) {
  if (dir == NULL || slot != 1) {
    errno = ENOENT;
    return -1;
  };
  int cnt = 0;
  for (std::map<std::string, int>::const_iterator it = path_to_inode.begin();
    it != path_to_inode.end(); ++it) {
    cnt += sizeof(struct dirent);
    if (cnt > static_cast<int>(count)) {
      cnt -= sizeof(struct dirent);
      break;
    }
    memset(dir, 0, sizeof(struct dirent));
    // We want d_ino to be non-zero because readdir()
    // will return null if d_ino is zero.
    dir->d_ino = 0x60061E;
    dir->d_reclen = sizeof(struct dirent);
    strncpy(dir->d_name, it->first.c_str(), sizeof(dir->d_name));
  }
  return cnt;
}

ssize_t DevMount::Read(ino_t slot, off_t offset, void *buf, size_t count) {
  if (buf == NULL) {
    errno = ENOENT;
    return -1;
  };
  if (inode_to_path.find(slot) != inode_to_path.end()) {
    return inode_to_dev[slot]->Read(offset, buf, count);
  } else {
    errno = ENOENT;
    return -1;
  }
}

ssize_t DevMount::Write(ino_t slot, off_t offset, const void *buf,
                        size_t count) {
  if (buf == NULL) {
    errno = ENOENT;
    return -1;
  };
  if (inode_to_path.find(slot) != inode_to_path.end()) {
    return inode_to_dev[slot]->Write(offset, buf, count);
  } else {
    errno = ENOENT;
    return -1;
  }
}

