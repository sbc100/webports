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

TEST(DevTest, Simple) {
  struct stat buf;
  EXPECT_EQ(0, stat("/dev/random", &buf));
  int h = open("/dev/random", O_RDONLY);
  EXPECT_GT(h, 0);
  char buff[5];
  EXPECT_EQ(5, read(h, reinterpret_cast<void*>(buff), 5));

  EXPECT_EQ(0, stat("/dev/urandom", &buf));
  int h2 = open("/dev/urandom", O_RDONLY);
  EXPECT_GT(h2, 0);
  EXPECT_EQ(5, read(h2, reinterpret_cast<void*>(buff), 5));

  int q = open("/dev/null", O_RDWR);
  EXPECT_EQ(5, write(q, reinterpret_cast<void*>(buff), 5));
  EXPECT_EQ(0, read(q, reinterpret_cast<void*>(buff), 5));
}
