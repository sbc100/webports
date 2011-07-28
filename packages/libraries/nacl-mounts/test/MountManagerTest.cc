/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include "../base/BaseMount.h"
#include "../base/MountManager.h"
#include "gtest/gtest.h"

TEST(MountManagerTest, AddRemoveMount) {
  MountManager *mm = new MountManager();
  BaseMount *mnt = new BaseMount();

  // should start with a default mount at "/"
  EXPECT_EQ(-1, mm->AddMount(mnt, "/"));
  EXPECT_EQ(0, mm->RemoveMount("/"));

  EXPECT_EQ(0, mm->AddMount(mnt, "/"));
  EXPECT_EQ(0, mm->AddMount(mnt, "/hi"));
  EXPECT_EQ(-1, mm->AddMount(mnt, "/hi"));
  EXPECT_EQ(0, mm->RemoveMount("/hi"));
  EXPECT_EQ(-1, mm->RemoveMount("/hi"));
  EXPECT_EQ(-1, mm->RemoveMount("/hi"));
  EXPECT_EQ(0, mm->AddMount(mnt, "/hi"));
  EXPECT_EQ(0, mm->RemoveMount("/hi"));
  EXPECT_EQ(0, mm->RemoveMount("/"));
  EXPECT_EQ(-1, mm->RemoveMount("/"));
  EXPECT_EQ(0, mm->AddMount(mnt, "/"));

  BaseMount *mnt2 = new BaseMount();
  EXPECT_EQ(-1, mm->AddMount(mnt2, "/"));
  EXPECT_EQ(0, mm->AddMount(mnt2, "/usr/local/mount2"));

  BaseMount *mnt3 = new BaseMount();
  EXPECT_EQ(0, mm->AddMount(mnt3, "/usr/local/mount3"));
  // remove all of the mounts
  EXPECT_EQ(0, mm->RemoveMount("/"));
  EXPECT_EQ(0, mm->RemoveMount("/usr/local/mount2"));
  EXPECT_EQ(0, mm->RemoveMount("/usr/local/mount3"));

  EXPECT_EQ(-2, mm->AddMount(NULL, "/usr/share"));
  EXPECT_EQ(-3, mm->AddMount(mnt, ""));
  EXPECT_EQ(-3, mm->AddMount(mnt, NULL));
  EXPECT_NE(0, mm->AddMount(NULL, ""));

  mm->ClearMounts();
}

TEST(MountManagerTest, GetMount) {
  MountManager *mm = new MountManager();
  mm->ClearMounts();
  std::pair<Mount *, std::string> ret;
  BaseMount *mnt = new BaseMount();

  EXPECT_EQ(0, mm->AddMount(mnt, "/"));
  ret = mm->GetMount("/");
  EXPECT_EQ(ret.first, mnt);
  EXPECT_EQ("/", ret.second);
  ret = mm->GetMount("/usr/local/hi");
  EXPECT_EQ(mnt, ret.first);
  EXPECT_EQ("usr/local/hi", ret.second);

  BaseMount *mnt2 = new BaseMount();
  EXPECT_EQ(0, mm->AddMount(mnt2, "/home/hi/mount2"));
  ret = mm->GetMount("/home/hi/mount2");
  EXPECT_EQ(mnt2, ret.first);
  EXPECT_EQ("/", ret.second);
  ret = mm->GetMount("/home/hi/mount2/go/down/deeper");
  EXPECT_EQ(ret.first, mnt2);
  EXPECT_EQ("/go/down/deeper", ret.second);
  ret = mm->GetMount("/home/hi");
  EXPECT_EQ(mnt, ret.first);
  EXPECT_EQ("home/hi", ret.second);
  std::string s;
  ret = mm->GetMount(s);
  EXPECT_EQ(0, static_cast<int>(ret.second.length()));

  mm->ClearMounts();
}
