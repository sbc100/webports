/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef LIBRARIES_NACL_MOUNTS_TEST_MOCKMOUNT_H_
#define LIBRARIES_NACL_MOUNTS_TEST_MOCKMOUNT_H_

#include <list>
#include <string>
#include <vector>
#include "base/Mount.h"


// A mock mount that can be programmed with canned responses for unit testing.
class MockMount : public Mount {
 public:
  MockMount();
  ~MockMount();
  // Add expectation of a return code and errno value.
  void AndReturn(int return_code, int errno_code);
  // Puts the mock into playback mode.
  void Playback(void);

  virtual int GetNode(const std::string& path, struct stat *st);
  virtual void Ref(ino_t node);
  virtual void Unref(ino_t node);
  virtual int Creat(const std::string& path, mode_t mode, struct stat *st);
  virtual int Mkdir(const std::string& path, mode_t mode, struct stat *st);
  virtual int Unlink(const std::string& path);
  virtual int Rmdir(ino_t node);
  virtual int Chmod(ino_t node, mode_t mode);
  virtual int Stat(ino_t node, struct stat *buf);
  virtual int Fsync(ino_t node);
  virtual int Getdents(ino_t node, off_t offset, struct dirent *dirp,
                       unsigned int count);
  virtual ssize_t Read(ino_t node, off_t offset, void *buf, size_t count);
  virtual ssize_t Write(ino_t node, off_t offset, const void *buf,
                        size_t count);
  virtual int Isatty(ino_t node);

 private:
  struct Operation {
    enum {
      MockGetNode,
      MockRef,
      MockUnref,
      MockCreat,
      MockMkdir,
      MockUnlink,
      MockRmdir,
      MockChmod,
      MockStat,
      MockFsync,
      MockGetdents,
      MockRead,
      MockWrite,
      MockIsatty,
    } kind;
    // Inputs.
    std::string path;
    mode_t mode;
    ino_t node;
    off_t offset;
    size_t count;
    std::vector<char> data_in;
    std::vector<struct dirent> dirp;

    // Outputs.
    int return_code;
    int errno_code;
    struct stat st;
    std::vector<char> data_out;

    Operation();
  };

  std::list<Operation> expected_;
  bool playback_mode_;

  // Pop an operation (done to work around gtest void return limitation).
  void PopOperation(Operation *op);

  DISALLOW_COPY_AND_ASSIGN(MockMount);
};

#endif  // LIBRARIES_NACL_MOUNTS_TEST_MOCKMOUNT_H_
