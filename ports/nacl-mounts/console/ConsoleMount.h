/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_CONSOLE_CONSOLEMOUNT_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_CONSOLE_CONSOLEMOUNT_H_

#include <string>
#include "../base/BaseMount.h"
#include "../util/macros.h"

// ConsoleMount is used to re-direct I/O to the console.  This mount
// assumes the following paths:
//    /dev/fd/0 for stdin
//    /dev/fd/1 for stdout
//    /dev/fd/2 for stderr
// The reads and writes are then directed to the real files corresponding to
// the file  descriptors STDIN_FILENO, STDOUT_FILENO, and STDERR_FILENO.
class ConsoleMount: public BaseMount {
 public:
  ConsoleMount() {}
  virtual ~ConsoleMount() {}

  // Creat() is successful if the path is "/dev/fd/0", "/dev/fd/1",
  // or "/def/fd/2".  Otherwise, Creat() fails.
  int Creat(const std::string& path, mode_t mode, struct stat* st);

  // GetNode() is successful if the path is "/dev/fd/0", "/dev/fd/1",
  // or "/def/fd/2".  Otherwise, GetNode() fails.
  int GetNode(const std::string& path, struct stat* st);

  int Stat(ino_t node, struct stat *buf);
  ssize_t Read(ino_t node, off_t offset, void *buf, size_t count);
  ssize_t Write(ino_t node, off_t offset, const void *buf, size_t count);
  int Isatty(ino_t node) { return 1; }

 private:
  DISALLOW_COPY_AND_ASSIGN(ConsoleMount);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_CONSOLE_CONSOLEMOUNT_H_
