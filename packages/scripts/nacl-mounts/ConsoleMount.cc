/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <stdio.h>
#include "ConsoleMount.h"

static const char *kSTDIN_PATH = "/dev/fd/0";
static const char *kSTDOUT_PATH = "/dev/fd/1";
static const char *kSTDERR_PATH = "/dev/fd/2";

static const ino_t kSTDIN_INO = 1;
static const ino_t kSTDOUT_INO = 2;
static const ino_t kSTDERR_INO = 3;

extern "C" {
  ssize_t __real_read(int fd, void *buf, size_t count);
  ssize_t __real_write(int fd, const void *buf, size_t count);
}

int ConsoleMount::Creat(const std::string& path, mode_t mode,
                        struct stat* buf) {
  return GetNode(path, buf);
}

int ConsoleMount::GetNode(const std::string& path, struct stat* buf) {
  if (path == kSTDIN_PATH) {
    return Stat(kSTDIN_INO, buf);
  }
  if (path == kSTDOUT_PATH) {
    return Stat(kSTDOUT_INO, buf);
  }
  if (path == kSTDERR_PATH) {
    return Stat(kSTDERR_INO, buf);
  }
  return -1;
}

int ConsoleMount::Stat(ino_t node, struct stat *buf) {
  memset(buf, 0, sizeof(struct stat));
  buf->st_ino = node;
  buf->st_mode = S_IFREG | 0777;
  return 0;
}

ssize_t ConsoleMount::Read(ino_t slot, off_t offset, void *buf, size_t count) {
  if (slot == kSTDIN_INO) {
    return __real_read(STDIN_FILENO, buf, count);
  }
  if (slot == kSTDOUT_INO) {
    return __real_read(STDOUT_FILENO, buf, count);
  }
  if (slot == kSTDERR_INO) {
    return __real_read(STDERR_FILENO, buf, count);
  }
  errno = ENOENT;
  return -1;
}

ssize_t ConsoleMount::Write(ino_t slot, off_t offset, const void *buf,
                            size_t count) {
  if (slot == kSTDIN_INO) {
    return __real_write(STDIN_FILENO, buf, count);
  }
  if (slot == kSTDOUT_INO) {
    return __real_write(STDOUT_FILENO, buf, count);
  }
  if (slot == kSTDERR_INO) {
    return __real_write(STDERR_FILENO, buf, count);
  }
  errno = ENOENT;
  return -1;
}
