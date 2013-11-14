/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include "gtest/gtest.h"
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

TEST(DupTest, Simple) {
  char buff[5];

  int random = open("/dev/random", O_RDONLY);
  EXPECT_GT(random, 0);
  int null = open("/dev/null", O_RDWR);
  EXPECT_GT(null, 0);

  // dup should work and take a reference.
  int null_copy = dup(null);
  EXPECT_GT(null_copy, 0);
  EXPECT_EQ(5, write(null, reinterpret_cast<void*>(buff), 5));
  EXPECT_EQ(0, read(null, reinterpret_cast<void*>(buff), 5));

  EXPECT_EQ(0, close(null));
  EXPECT_EQ(5, write(null_copy, reinterpret_cast<void*>(buff), 5));
  EXPECT_EQ(0, read(null_copy, reinterpret_cast<void*>(buff), 5));

  // dup2 with oldfd == newfd is a no-op.
  EXPECT_EQ(null_copy, dup2(null_copy, null_copy));

  // dup2 should work on a high fd and take a reference.
  EXPECT_EQ(99, dup2(null_copy, 99));
  EXPECT_EQ(5, write(null_copy, reinterpret_cast<void*>(buff), 5));
  EXPECT_EQ(0, read(null_copy, reinterpret_cast<void*>(buff), 5));

  EXPECT_EQ(0, close(null_copy));
  EXPECT_EQ(5, write(99, reinterpret_cast<void*>(buff), 5));
  EXPECT_EQ(0, read(99, reinterpret_cast<void*>(buff), 5));

  // dup2 should close newfd if needbe.
  EXPECT_EQ(random, dup2(99, random));
  EXPECT_EQ(5, write(99, reinterpret_cast<void*>(buff), 5));
  EXPECT_EQ(0, read(99, reinterpret_cast<void*>(buff), 5));

  EXPECT_EQ(0, close(99));
  EXPECT_EQ(5, write(random, reinterpret_cast<void*>(buff), 5));
  EXPECT_EQ(0, read(random, reinterpret_cast<void*>(buff), 5));
}
