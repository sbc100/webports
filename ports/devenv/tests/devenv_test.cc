// Copyright (c) 2014 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "gtest/gtest.h"

// Make sure that the plumbing works.
TEST(Plumbing, Identity) {
  EXPECT_EQ(0, 0);
}

// Test process functions.
TEST(Plumbing, ProcessTests) {
  int pid = getpid();
  EXPECT_GT(pid, 1);
  EXPECT_GT(getppid(), 0);
  EXPECT_EQ(setpgrp(), 0);
  EXPECT_EQ(getpgid(0), pid);
  EXPECT_EQ(getpgrp(), pid);
  EXPECT_EQ(setsid(), -1);
}

extern "C" int nacl_main(int argc, char **argv) {
  testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
