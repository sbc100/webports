/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <errno.h>
#include <list>
#include "buffer/BufferMount.h"
#include "test/MockMount.h"
#include "gtest/gtest.h"


// Size of buffer / chunks to test.
static const int kTestChunkSize = 1024;
static const int kTestMaxChunks = 10;

// Prime numbers for deterministic pattern.
static const int kPrime0 = 7;
static const int kPrime1 = 733;
static const int kPrime2 = 331;
static const int kPrime3 = (1U << 31) - 1;

static char DeterministicPattern(int seed, off_t offset) {
  return (kPrime0 + seed * kPrime1 + offset * kPrime2) % kPrime3;
}


static void DeterministicFill(int seed, off_t offset,
                              size_t count, char *dst) {
  for (size_t i = 0; i < count; ++i) {
    dst[i] = DeterministicPattern(seed, i + offset);
  }
}

static void DeterministicCheck(int seed, off_t offset,
                               size_t count, const char *src) {
  for (size_t i = 0; i < count; ++i) {
    ASSERT_EQ(src[i], DeterministicPattern(seed, i + offset));
  }
}

TEST(BufferMountTest, Sanity) {
  MockMount mm;
  BufferMount bm(&mm, kTestChunkSize, kTestMaxChunks);

  mm.Playback();
}

TEST(BufferMountTest, Directories) {
  MockMount mm;
  BufferMount bm(&mm, kTestChunkSize, kTestMaxChunks);

  struct stat st;
  memset(&st, 0, sizeof(st));
  st.st_ino = 123;
  mm.Mkdir("/dir1", 0, &st);
  mm.Rmdir(st.st_ino);

  mm.Playback();

  bm.Mkdir("/dir1", 0, &st);
  bm.Rmdir(st.st_ino);
}

TEST(BufferMountTest, Isatty) {
  MockMount mm;
  BufferMount bm(&mm, kTestChunkSize, kTestMaxChunks);

  static const ino_t tty = 123;
  static const ino_t nontty = 456;

  mm.Isatty(tty);
  mm.AndReturn(1, 0);
  mm.Isatty(nontty);
  mm.AndReturn(0, 0);

  mm.Playback();

  EXPECT_TRUE(bm.Isatty(tty));
  EXPECT_FALSE(bm.Isatty(nontty));
}

TEST(BufferMountTest, ReadSmall) {
  MockMount mm;
  BufferMount bm(&mm, kTestChunkSize, kTestMaxChunks);

  struct stat st;
  st.st_ino = 123;

  const int file_size = 431;
  char* buf = new char[kTestChunkSize];
  DeterministicFill(0, 0, file_size, buf);

  mm.GetNode("/small.txt", &st);
  mm.Read(st.st_ino, 0, buf, kTestChunkSize);
  mm.AndReturn(file_size, 0);

  mm.Playback();

  struct stat nst;
  EXPECT_EQ(0, bm.GetNode("/small.txt", &nst));
  EXPECT_EQ(nst.st_ino, st.st_ino);

  // Read 5 times.
  for (int i = 0; i < 5; ++i) {
    char buf2[512];
    memset(buf2, 0, sizeof(buf2));
    EXPECT_EQ(file_size, bm.Read(nst.st_ino, 0, buf2, sizeof(buf2)));
    DeterministicCheck(0, 0, file_size, buf2);
  }

  // Read 5 times with offset.
  for (int i = 0; i < 5; ++i) {
    char buf2[512];
    memset(buf2, 0, sizeof(buf2));
    EXPECT_EQ(file_size - 11, bm.Read(nst.st_ino, 11, buf2, sizeof(buf2)));
    DeterministicCheck(0, 11, file_size - 11, buf2);
  }

  delete[] buf;
}

TEST(BufferMountTest, ReadLarge) {
  MockMount mm;
  BufferMount bm(&mm, kTestChunkSize, kTestMaxChunks);

  struct stat st;
  st.st_ino = 123;

  const int file_size = 4310;
  char* buf = new char[file_size];
  DeterministicFill(0, 0, file_size, buf);

  mm.GetNode("/large.txt", &st);
  int range = (file_size - 1) / kTestChunkSize + 1;
  for (int i = 0; i < range; ++i) {
    mm.Read(st.st_ino, i * kTestChunkSize, buf, kTestChunkSize);
    if (i == range - 1) {
      mm.AndReturn(file_size % kTestChunkSize, 0);
    } else {
      mm.AndReturn(kTestChunkSize, 0);
    }
  }

  mm.Playback();

  struct stat nst;
  EXPECT_EQ(0, bm.GetNode("/large.txt", &nst));
  EXPECT_EQ(nst.st_ino, st.st_ino);

  // Read 5 times.
  for (int i = 0; i < 5; ++i) {
    char buf2[5000];
    memset(buf2, 0, sizeof(buf2));
    EXPECT_EQ(file_size, bm.Read(nst.st_ino, 0, buf2, sizeof(buf2)));
    DeterministicCheck(0, 0, file_size, buf2);
  }

  // Read 5 times with offset.
  for (int i = 0; i < 5; ++i) {
    char buf2[5000];
    memset(buf2, 0, sizeof(buf2));
    EXPECT_EQ(file_size - 11, bm.Read(nst.st_ino, 11, buf2, sizeof(buf2)));
    DeterministicCheck(0, 11, file_size - 11, buf2);
  }

  delete[] buf;
}

TEST(BufferMountTest, ReadLargeOffset) {
  MockMount mm;
  BufferMount bm(&mm, kTestChunkSize, kTestMaxChunks);

  struct stat st;
  st.st_ino = 123;

  const int file_size = 4310;
  char* buf = new char[file_size];
  DeterministicFill(0, 0, file_size, buf);

  mm.GetNode("/large.txt", &st);
  int range = (file_size - 1) / kTestChunkSize + 1;
  for (int i = 0; i < range; ++i) {
    mm.Read(st.st_ino, i * kTestChunkSize, buf, kTestChunkSize);
    if (i == range - 1) {
      mm.AndReturn(file_size % kTestChunkSize, 0);
    } else {
      mm.AndReturn(kTestChunkSize, 0);
    }
  }

  mm.Playback();

  struct stat nst;
  EXPECT_EQ(0, bm.GetNode("/large.txt", &nst));
  EXPECT_EQ(nst.st_ino, st.st_ino);

  // Read 5 times with offset right away.
  for (int i = 0; i < 5; ++i) {
    char buf2[5000];
    memset(buf2, 0, sizeof(buf2));
    EXPECT_EQ(file_size - 11, bm.Read(nst.st_ino, 11, buf2, sizeof(buf2)));
    DeterministicCheck(0, 11, file_size - 11, buf2);
  }

  delete[] buf;
}

TEST(BufferMountTest, ReadLargeMiddle) {
  MockMount mm;
  BufferMount bm(&mm, kTestChunkSize, kTestMaxChunks);

  struct stat st;
  st.st_ino = 123;

  const int file_size = 7310;
  char* buf = new char[file_size];
  DeterministicFill(0, 0, file_size, buf);

  mm.GetNode("/large.txt", &st);
  for (int i = 2; i < 5; ++i) {
    mm.Read(st.st_ino, i * kTestChunkSize,
            buf + i * kTestChunkSize, kTestChunkSize);
    mm.AndReturn(kTestChunkSize, 0);
  }

  mm.Playback();

  struct stat nst;
  EXPECT_EQ(0, bm.GetNode("/large.txt", &nst));
  EXPECT_EQ(nst.st_ino, st.st_ino);

  // Read 5 times with offset right away.
  for (int i = 0; i < 5; ++i) {
    char buf2[1500];
    memset(buf2, 0, sizeof(buf2));
    EXPECT_EQ(static_cast<int>(sizeof(buf2)),
              bm.Read(nst.st_ino, 2000, buf2, sizeof(buf2)));
    DeterministicCheck(0, 2000, sizeof(buf2), buf2);
  }

  delete[] buf;
}

TEST(BufferMountTest, ReadOverflow) {
  for (int skew = -1; skew <= 1; ++skew) {
    MockMount mm;
    BufferMount bm(&mm, kTestChunkSize, kTestMaxChunks);

    struct stat st;
    st.st_ino = 123;

    const int file_size = kTestChunkSize * (kTestMaxChunks + 1) + skew;
    char* buf = new char[file_size + kTestChunkSize];
    DeterministicFill(skew, 0, file_size, buf);

    mm.GetNode("/huge.txt", &st);

    for (int j = 0; j < 5; j++) {
      size_t offset = 0;
      while (offset <= size_t(file_size)) {
        offset = offset / kTestChunkSize * kTestChunkSize;
        mm.Read(st.st_ino, offset, buf + offset, kTestChunkSize);
        if (size_t(file_size) >= kTestChunkSize + offset) {
          mm.AndReturn(kTestChunkSize, 0);
          offset += kTestChunkSize;
        } else {
          mm.AndReturn(file_size - offset, 0);
          break;
        }
      }
    }

    mm.Playback();

    struct stat nst;
    EXPECT_EQ(0, bm.GetNode("/huge.txt", &nst));
    EXPECT_EQ(nst.st_ino, st.st_ino);

    // Read 5 times with offset right away.
    for (int i = 0; i < 5; ++i) {
      int buf2_size = file_size + 600;
      char* buf2 = new char[buf2_size];
      memset(buf2, 0, buf2_size);
      EXPECT_EQ(file_size - 11, bm.Read(nst.st_ino, 11, buf2, buf2_size));
      DeterministicCheck(skew, 11, file_size - 11, buf2);
      delete[] buf2;
    }

    delete[] buf;
  }
}

TEST(BufferMountTest, Invalidate) {
  MockMount mm;
  BufferMount bm(&mm, kTestChunkSize, kTestMaxChunks);

  struct stat st;
  st.st_ino = 123;

  const int file_size = 431;
  char* buf = new char[kTestChunkSize];
  DeterministicFill(0, 0, file_size, buf);

  mm.GetNode("/small.txt", &st);
  mm.Ref(st.st_ino);

  mm.Read(st.st_ino, 0, buf, kTestChunkSize);
  mm.AndReturn(file_size, 0);

  mm.Unref(st.st_ino);

  mm.Read(st.st_ino, 0, buf, kTestChunkSize);
  mm.AndReturn(file_size, 0);

  mm.GetNode("/small.txt", &st);
  mm.Unlink("/small.txt");

  mm.Read(st.st_ino, 0, buf, kTestChunkSize);
  mm.AndReturn(file_size, 0);

  mm.Rmdir(st.st_ino);

  mm.Read(st.st_ino, 0, buf, kTestChunkSize);
  mm.AndReturn(file_size, 0);

  mm.Write(st.st_ino, 0, 0, 0);

  mm.Read(st.st_ino, 0, buf, kTestChunkSize);
  mm.AndReturn(file_size, 0);

  mm.Playback();

  struct stat nst;
  EXPECT_EQ(0, bm.GetNode("/small.txt", &nst));
  EXPECT_EQ(nst.st_ino, st.st_ino);
  bm.Ref(st.st_ino);

  // Mixed with cache invalidating ops.
  char buf2[512];

  memset(buf2, 0, sizeof(buf2));
  EXPECT_EQ(file_size, bm.Read(nst.st_ino, 0, buf2, sizeof(buf2)));
  DeterministicCheck(0, 0, file_size, buf2);

  bm.Unref(nst.st_ino);

  memset(buf2, 0, sizeof(buf2));
  EXPECT_EQ(file_size, bm.Read(nst.st_ino, 0, buf2, sizeof(buf2)));
  DeterministicCheck(0, 0, file_size, buf2);

  bm.Unlink("/small.txt");

  memset(buf2, 0, sizeof(buf2));
  EXPECT_EQ(file_size, bm.Read(nst.st_ino, 0, buf2, sizeof(buf2)));
  DeterministicCheck(0, 0, file_size, buf2);

  bm.Rmdir(nst.st_ino);

  memset(buf2, 0, sizeof(buf2));
  EXPECT_EQ(file_size, bm.Read(nst.st_ino, 0, buf2, sizeof(buf2)));
  DeterministicCheck(0, 0, file_size, buf2);

  bm.Write(nst.st_ino, 0, 0, 0);

  memset(buf2, 0, sizeof(buf2));
  EXPECT_EQ(file_size, bm.Read(nst.st_ino, 0, buf2, sizeof(buf2)));
  DeterministicCheck(0, 0, file_size, buf2);

  delete[] buf;
}
