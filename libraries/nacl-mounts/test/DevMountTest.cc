/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "../dev/DevMount.h"
#include "gtest/gtest.h"

TEST(DevMountTest, Sanity) {
  DevMount* bm = new DevMount();

  // just make sure all of the calls run
  struct stat st;
  struct dirent dir;
  EXPECT_EQ(bm->GetNode("/", &st), 0);
  EXPECT_EQ(0, bm->Stat(1, &st));
  EXPECT_EQ(1, S_ISDIR(st.st_mode));
  EXPECT_GT(bm->Getdents(1, 0, &dir, 1024), 1);
  bm->GetNode("/null", &st);
  int node = st.st_ino;
  char buf[10];
  EXPECT_EQ(5, bm->Write(node, 0, reinterpret_cast<void*>(buf), 5));
  EXPECT_EQ(0, bm->Isatty(0));
}

