/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "gtest/gtest.h"

#include <fcntl.h>
#include <sys/types.h>
#ifdef __GLIBC__
#include <sys/select.h>
#endif
#include <sys/stat.h>
#include <unistd.h>

#include <algorithm>

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

#ifdef __GLIBC___
TEST(DevTest, Select) {
  int random = open("/dev/random", O_RDONLY);
  EXPECT_GT(random, 0);
  int null = open("/dev/null", O_RDWR);
  EXPECT_GT(null, 0);

  fd_set readfds, writefds, exceptfds;
  FD_ZERO(&readfds);
  FD_ZERO(&writefds);
  FD_ZERO(&exceptfds);

  FD_SET(random, &readfds);
  FD_SET(null, &readfds);
  FD_SET(random, &writefds);
  FD_SET(null, &writefds);
  FD_SET(random, &exceptfds);
  FD_SET(null, &exceptfds);

  struct timeval timeout = { 0, 0 };
  EXPECT_EQ(3, select(std::max(random, null) + 1,
                      &readfds, &writefds, &exceptfds, &timeout));

  EXPECT_TRUE(FD_ISSET(random, &readfds));
  EXPECT_TRUE(FD_ISSET(null, &readfds));

  EXPECT_FALSE(FD_ISSET(random, &writefds));
  EXPECT_TRUE(FD_ISSET(null, &writefds));

  EXPECT_FALSE(FD_ISSET(random, &exceptfds));
  EXPECT_FALSE(FD_ISSET(null, &exceptfds));
}
#endif
