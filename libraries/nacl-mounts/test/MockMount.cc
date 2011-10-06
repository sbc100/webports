/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "test/MockMount.h"
#include <errno.h>
#include "gtest/gtest.h"


MockMount::MockMount() {
  playback_mode_ = false;
}

MockMount::~MockMount() {
  EXPECT_TRUE(playback_mode_);
  EXPECT_TRUE(expected_.empty());
}

void MockMount::AndReturn(int return_code, int errno_code) {
  ASSERT_FALSE(expected_.empty());
  expected_.back().return_code = return_code;
  expected_.back().errno_code = errno_code;
}

void MockMount::Playback(void) {
  EXPECT_EQ(false, playback_mode_);
  playback_mode_ = true;
}

int MockMount::GetNode(const std::string& path, struct stat *st) {
  if (playback_mode_) {
    Operation op;
    PopOperation(&op);
    EXPECT_EQ(Operation::MockGetNode, op.kind);
    EXPECT_EQ(op.path, path);
    *st = op.st;
    errno = op.errno_code;
    return op.return_code;
  } else {
    Operation op;
    op.kind = Operation::MockGetNode;
    op.path = path;
    op.st = *st;
    expected_.push_back(op);
    return 0;
  }
}

void MockMount::Ref(ino_t node) {
  if (playback_mode_) {
    Operation op;
    PopOperation(&op);
    EXPECT_EQ(Operation::MockRef, op.kind);
    EXPECT_EQ(op.node, node);
  } else {
    Operation op;
    op.kind = Operation::MockRef;
    op.node = node;
    expected_.push_back(op);
  }
}

void MockMount::Unref(ino_t node) {
  if (playback_mode_) {
    Operation op;
    PopOperation(&op);
    EXPECT_EQ(Operation::MockUnref, op.kind);
    EXPECT_EQ(op.node, node);
  } else {
    Operation op;
    op.kind = Operation::MockUnref;
    op.node = node;
    expected_.push_back(op);
  }
}

int MockMount::Creat(const std::string& path, mode_t mode, struct stat *st) {
  if (playback_mode_) {
    Operation op;
    PopOperation(&op);
    EXPECT_EQ(Operation::MockCreat, op.kind);
    EXPECT_EQ(op.path, path);
    EXPECT_EQ(op.mode, mode);
    *st = op.st;
    errno = op.errno_code;
    return op.return_code;
  } else {
    Operation op;
    op.kind = Operation::MockCreat;
    op.path = path;
    op.mode = mode;
    op.st = *st;
    expected_.push_back(op);
    return 0;
  }
}

int MockMount::Mkdir(const std::string& path, mode_t mode, struct stat *st) {
  if (playback_mode_) {
    Operation op;
    PopOperation(&op);
    EXPECT_EQ(Operation::MockMkdir, op.kind);
    EXPECT_EQ(op.mode, mode);
    EXPECT_EQ(op.path, path);
    *st = op.st;
    errno = op.errno_code;
    return op.return_code;
  } else {
    Operation op;
    op.kind = Operation::MockMkdir;
    op.path = path;
    op.mode = mode;
    op.st = *st;
    expected_.push_back(op);
    return 0;
  }
}

int MockMount::Unlink(const std::string& path) {
  if (playback_mode_) {
    Operation op;
    PopOperation(&op);
    EXPECT_EQ(Operation::MockUnlink, op.kind);
    EXPECT_EQ(op.path, path);
    errno = op.errno_code;
    return op.return_code;
  } else {
    Operation op;
    op.kind = Operation::MockUnlink;
    op.path = path;
    expected_.push_back(op);
    return 0;
  }
}

int MockMount::Rmdir(ino_t node) {
  if (playback_mode_) {
    Operation op;
    PopOperation(&op);
    EXPECT_EQ(Operation::MockRmdir, op.kind);
    EXPECT_EQ(op.node, node);
    errno = op.errno_code;
    return op.return_code;
  } else {
    Operation op;
    op.kind = Operation::MockRmdir;
    op.node = node;
    expected_.push_back(op);
    return 0;
  }
}

int MockMount::Chmod(ino_t node, mode_t mode) {
  if (playback_mode_) {
    Operation op;
    PopOperation(&op);
    EXPECT_EQ(Operation::MockChmod, op.kind);
    EXPECT_EQ(op.node, node);
    EXPECT_EQ(op.mode, mode);
    errno = op.errno_code;
    return op.return_code;
  } else {
    Operation op;
    op.kind = Operation::MockChmod;
    op.node = node;
    op.mode = mode;
    expected_.push_back(op);
    return 0;
  }
}

int MockMount::Stat(ino_t node, struct stat *buf) {
  if (playback_mode_) {
    Operation op;
    PopOperation(&op);
    EXPECT_EQ(Operation::MockStat, op.kind);
    EXPECT_EQ(op.node, node);
    *buf = op.st;
    errno = op.errno_code;
    return op.return_code;
  } else {
    Operation op;
    op.kind = Operation::MockStat;
    op.node = node;
    op.st = *buf;
    expected_.push_back(op);
    return 0;
  }
}

int MockMount::Fsync(ino_t node) {
  if (playback_mode_) {
    Operation op;
    PopOperation(&op);
    EXPECT_EQ(Operation::MockFsync, op.kind);
    EXPECT_EQ(op.node, node);
    errno = op.errno_code;
    return op.return_code;
  } else {
    Operation op;
    op.kind = Operation::MockFsync;
    op.node = node;
    expected_.push_back(op);
    return 0;
  }
}

int MockMount::Getdents(ino_t node, off_t offset, struct dirent *dirp,
                        unsigned int count) {
  if (playback_mode_) {
    Operation op;
    PopOperation(&op);
    EXPECT_EQ(Operation::MockGetdents, op.kind);
    EXPECT_EQ(op.node, node);
    EXPECT_EQ(op.offset, offset);
    EXPECT_LE(op.count, count);
    if (op.return_code >= 0) {
      memcpy(dirp, &op.dirp[0], op.return_code);
    }
    errno = op.errno_code;
    return op.return_code;
  } else {
    Operation op;
    op.kind = Operation::MockGetdents;
    op.node = node;
    op.offset = offset;
    EXPECT_EQ(count % sizeof(struct dirent), size_t(0));
    op.dirp.resize(count / sizeof(struct dirent));
    memcpy(&op.dirp[0], dirp, count);
    expected_.push_back(op);
    return 0;
  }
}

ssize_t MockMount::Read(ino_t node, off_t offset, void *buf, size_t count) {
  if (playback_mode_) {
    Operation op;
    PopOperation(&op);
    EXPECT_EQ(Operation::MockRead, op.kind);
    EXPECT_EQ(op.node, node);
    EXPECT_EQ(op.count, count);
    if (op.return_code >= 0) {
      memcpy(buf, &op.data_out[0], op.return_code);
    }
    errno = op.errno_code;
    return op.return_code;
  } else {
    Operation op;
    op.kind = Operation::MockRead;
    op.node = node;
    op.count = count;
    op.data_out.resize(count);
    memcpy(&op.data_out[0], buf, count);
    expected_.push_back(op);
    return 0;
  }
}

ssize_t MockMount::Write(ino_t node, off_t offset, const void *buf,
                         size_t count) {
  if (playback_mode_) {
    Operation op;
    PopOperation(&op);
    EXPECT_EQ(Operation::MockWrite, op.kind);
    EXPECT_EQ(op.node, node);
    EXPECT_EQ(op.data_in.size(), count);
    EXPECT_EQ(memcmp(buf, &op.data_in[0], count), 0);
    errno = op.errno_code;
    return op.return_code;
  } else {
    Operation op;
    op.kind = Operation::MockWrite;
    op.node = node;
    op.data_in.resize(count);
    memcpy(&op.data_in[0], buf, count);
    expected_.push_back(op);
    return 0;
  }
}

int MockMount::Isatty(ino_t node) {
  if (playback_mode_) {
    Operation op;
    PopOperation(&op);
    EXPECT_EQ(Operation::MockIsatty, op.kind);
    EXPECT_EQ(op.node, node);
    errno = op.errno_code;
    return op.return_code;
  } else {
    Operation op;
    op.kind = Operation::MockIsatty;
    op.node = node;
    expected_.push_back(op);
    return 0;
  }
}

MockMount::Operation::Operation() {
  mode = 0;
  memset(&st, 0, sizeof(st));
  node = 0;
  offset = 0;
  return_code = 0;
  errno_code = 0;
}

void MockMount::PopOperation(MockMount::Operation *op) {
  ASSERT_FALSE(expected_.empty());
  *op = expected_.front();
  expected_.pop_front();
}
