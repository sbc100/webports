/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include "../base/BaseMount.h"
#include "../base/KernelProxy.h"
#include "../base/MountManager.h"
#include "../memory/MemMount.h"
#include "gtest/gtest.h"

#define CHECK_WD(want) { \
  std::string wd; \
  EXPECT_TRUE(kp->getcwd(&wd, 300)); \
  EXPECT_EQ(want, wd); \
  wd.clear(); \
  EXPECT_TRUE(kp->getwd(&wd)); \
  EXPECT_EQ(want, wd); \
}

KernelProxy *kp = KernelProxy::KPInstance();
MountManager *mm = kp->mm();

TEST(KernelProxyTest, RoutedSysCalls) {
  // put in a mount
  mm->ClearMounts();
  BaseMount *mnt = new BaseMount();
  EXPECT_EQ(0, mm->AddMount(mnt, "/"));

  // Run through each sys call.
  // No call should do anything useful, but each should be able to run.
  const char *path = "/hi/there";
  int fd = 5;

  EXPECT_EQ(-1, kp->chmod(path, 0));
  EXPECT_EQ(-1, kp->remove(path));
  EXPECT_EQ(-1, kp->stat(path, NULL));
  EXPECT_EQ(-1, kp->access(path, 0));
  EXPECT_EQ(-1, kp->mkdir(path, 0));
  EXPECT_EQ(-1, kp->rmdir(path));
  EXPECT_EQ(-1, kp->open(path, 0, 0));

  EXPECT_EQ(-1, kp->close(fd));
  EXPECT_EQ(-1, kp->close(-10));
  EXPECT_EQ(-1, kp->read(fd, NULL, 0));
  EXPECT_EQ(-1, kp->write(fd, NULL, 0));
  EXPECT_EQ(-1, kp->fstat(fd, NULL));
  EXPECT_EQ(-1, kp->getdents(fd, NULL, 0));
  EXPECT_EQ(-1, kp->lseek(fd, 0, 0));
  EXPECT_EQ(0, kp->isatty(fd));

  EXPECT_EQ(0, mm->RemoveMount("/"));

  mm->ClearMounts();
}

TEST(KernelProxyTest, ChdirCwdWd) {
  mm->ClearMounts();
  MemMount *mnt1, *mnt2, *mnt3;
  mnt1 = new MemMount();
  // put in a mount
  EXPECT_EQ(0, mm->AddMount(mnt1, "/"));

  CHECK_WD("/");

  EXPECT_EQ(0, kp->mkdir("/hello/", 0));
  EXPECT_EQ(0, kp->mkdir("/hello/world", 0));


  EXPECT_EQ(0, kp->chdir("/hello/world"));
  CHECK_WD("/hello/world");
  EXPECT_EQ(0, kp->chdir("/hello"));
  CHECK_WD("/hello");
  EXPECT_EQ(0, kp->chdir("/hello/world"));
  CHECK_WD("/hello/world");
  EXPECT_EQ(-1, kp->chdir("/hello/world/hi"));
  CHECK_WD("/hello/world");
  EXPECT_EQ(-1, kp->chdir("/hi"));
  EXPECT_EQ(0, kp->chdir("/"));
  CHECK_WD("/");

  mnt2 = new MemMount();
  EXPECT_EQ(0, mm->AddMount(mnt2, "/usr/mount2"));
  EXPECT_EQ(-2, mm->AddMount(NULL, "/usr/mount3"));
  mnt3 = new MemMount();
  EXPECT_EQ(0, mm->AddMount(mnt3, "/usr/mount3"));
  EXPECT_EQ(0, kp->mkdir("/usr", 0));
  EXPECT_EQ(-1, kp->mkdir("/usr/mount2", 0));
  EXPECT_EQ(0, kp->mkdir("/usr/mount2/hello", 0));
  EXPECT_EQ(0, kp->mkdir("/usr/mount2/hello/world", 0));
  EXPECT_EQ(-1, kp->mkdir("/usr/mount3", 0));
  EXPECT_EQ(0, kp->chdir("/usr/mount2/hello/world"));
  CHECK_WD("/usr/mount2/hello/world");

  EXPECT_EQ(0, kp->chdir("/"));
  CHECK_WD("/");

  EXPECT_EQ(0, kp->chdir("/usr/mount2/hello"));
  CHECK_WD("/usr/mount2/hello");

  // Now we try some relative paths and ".."
  EXPECT_EQ(0, kp->chdir(".."));
  CHECK_WD("/usr/mount2");
  EXPECT_EQ(0, kp->chdir("/../..//"));
  CHECK_WD("/");
  EXPECT_EQ(0, kp->chdir("usr/mount2/hello/./"));
  CHECK_WD("/usr/mount2/hello");
  EXPECT_EQ(0, kp->mkdir("/usr/mount3/hello", 0));
  EXPECT_EQ(0, kp->chdir("../../mount3/hello"));
  CHECK_WD("/usr/mount3/hello");
  EXPECT_EQ(0, kp->mkdir("world", 0));
  EXPECT_EQ(0, kp->chdir("world"));
  CHECK_WD("/usr/mount3/hello/world");
  EXPECT_EQ(0, kp->chdir("."));
  CHECK_WD("/usr/mount3/hello/world");
  EXPECT_EQ(0, kp->chdir("../../../../../"));
  CHECK_WD("/");

  mm->ClearMounts();
}

TEST(KernelProxyTest, access) {
  mm->ClearMounts();
  MemMount *mnt = new MemMount();
  EXPECT_EQ(0, mm->AddMount(mnt, "/"));
  kp->chdir("/");

  EXPECT_EQ(0, kp->mkdir("/hello", 0));
  EXPECT_EQ(0, kp->mkdir("/hello/world", 0));
  int fd = kp->open("/hello/world/test.txt", O_CREAT, 0);
  EXPECT_NE(-1, fd);

  int amode = F_OK;
  EXPECT_EQ(0, kp->access("/hello/world/test.txt", amode));
  EXPECT_EQ(0, kp->access("/", amode));

  amode |= R_OK;
  EXPECT_EQ(0, kp->access("/hello/world/test.txt", amode));
  EXPECT_EQ(0, kp->access("/", amode));

  amode |= W_OK;
  EXPECT_EQ(0, kp->access("/hello/world/test.txt", amode));
  EXPECT_EQ(0, kp->access("/", amode));

  amode |= X_OK;
  EXPECT_EQ(0, kp->access("/hello/world/test.txt", amode));
  EXPECT_EQ(0, kp->access("/", amode));

  EXPECT_EQ(0, kp->chdir("/"));
  EXPECT_EQ(0, kp->access("/", amode));
  EXPECT_EQ(0, kp->access("hello/world/test.txt", amode));

  EXPECT_EQ(0, kp->close(fd));
}

TEST(KernelProxyTest, BasicOpen) {
  mm->ClearMounts();
  MemMount *mnt = new MemMount();
  EXPECT_EQ(0, mm->AddMount(mnt, "/"));
  kp->chdir("/");

  EXPECT_EQ(3, kp->open("/test.txt", O_CREAT, 0));
  EXPECT_EQ(4, kp->open("hi.txt", O_CREAT, 0));

  mm->ClearMounts();
}

TEST(KernelProxyTest, Stat) {
  mm->ClearMounts();
  MemMount *mnt = new MemMount();
  EXPECT_EQ(0, mm->AddMount(mnt, "/"));
  kp->chdir("/");

  ASSERT_LE(0, kp->mkdir("/MemMountTest_Stat", 0755));
  struct stat st;
  ASSERT_EQ(0, kp->stat("/MemMountTest_Stat", &st));
  ASSERT_TRUE(S_ISDIR(st.st_mode));
  ASSERT_FALSE(S_ISREG(st.st_mode));
  ASSERT_EQ(-1, kp->stat("/MemMountTest_Stat2", &st));
  int fd = kp->open("/MemMountTest_Stat/file", O_CREAT, 644);
  ASSERT_LE(0, fd);
  ASSERT_EQ(0, kp->stat("/MemMountTest_Stat/file", &st));
  ASSERT_FALSE(S_ISDIR(st.st_mode));
  ASSERT_TRUE(S_ISREG(st.st_mode));
}
