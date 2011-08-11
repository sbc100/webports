/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_UTIL_DIRENT_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_UTIL_DIRENT_H_

#include <stdint.h>
#include <sys/stat.h>

struct dirent {
  ino_t d_ino;
  off_t d_off;
  uint16_t d_reclen;
  char d_name[256];
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_UTIL_DIRENT_H_
