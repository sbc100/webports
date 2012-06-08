/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <nacl-mounts/base/KernelProxy.h>
#include "gtest/gtest.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

TEST(SimpleTest, Simple) {
  struct stat buf;
  EXPECT_EQ(0, stat("/", &buf));
  EXPECT_EQ(1, S_ISDIR(buf.st_mode));
  EXPECT_EQ(0, stat("/dev", &buf));
  EXPECT_EQ(1, S_ISDIR(buf.st_mode));
  EXPECT_EQ(0, stat("/dev/fd", &buf));
  EXPECT_EQ(1, S_ISDIR(buf.st_mode));

  EXPECT_EQ(-1, stat("/dummy", &buf));
}
