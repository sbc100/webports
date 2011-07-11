/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "BaseMount.h"
#include "gtest/gtest.h"

TEST(BaseMountTest, Sanity) {
  BaseMount *bm = new BaseMount();

  // just make sure all of the calls run
  EXPECT_EQ(-1, bm->GetNode("", NULL));
  EXPECT_EQ(-1, bm->Creat("", 0, NULL));
  EXPECT_EQ(-1, bm->Mkdir("", 0, NULL));
  EXPECT_EQ(-1, bm->Unlink(""));
  EXPECT_EQ(-1, bm->Rmdir(0));
  EXPECT_EQ(-1, bm->Chmod(0, 0));
  EXPECT_EQ(-1, bm->Stat(0, NULL));
  EXPECT_EQ(-1, bm->Fsync(0));
  EXPECT_EQ(-1, bm->Getdents(0, 0, NULL, 0));
  EXPECT_EQ(-1, bm->Read(0, 0, NULL, 0));
  EXPECT_EQ(-1, bm->Write(0, 0, NULL, 0));
}
