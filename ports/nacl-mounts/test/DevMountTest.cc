/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "../dev/DevMount.h"
#include "gtest/gtest.h"

TEST(DevMountTest, Sanity) {
  DevMount* dm = new DevMount();

  // just make sure all of the calls run
  struct stat st;
  struct dirent dir;
  EXPECT_EQ(dm->GetNode("/", &st), 0);
  EXPECT_EQ(0, dm->Stat(1, &st));
  EXPECT_EQ(1, S_ISDIR(st.st_mode));
  EXPECT_GT(dm->Getdents(1, 0, &dir, sizeof(struct dirent)*2), 1);
  dm->GetNode("/null", &st);
  int node = st.st_ino;
  char buf[10];
  EXPECT_EQ(5, dm->Write(node, 0, reinterpret_cast<void*>(buf), 5));
  EXPECT_EQ(0, dm->Isatty(0));
}

