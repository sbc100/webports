/* Copyright 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

#include <errno.h>
#include <stdlib.h>

#include "gtest/gtest.h"

TEST(TestMktemp, mkdtemp_errors) {
  char small[] = "small";
  char missing_template[] = "missing_template";
  char short_template_XXX[] = "short_template_XXX";
  char not_XXXXXX_suffix[] = "not_XXXXXX_suffix";
  ASSERT_EQ((char*)NULL, mkdtemp(small));
  ASSERT_EQ(EINVAL, errno);
  ASSERT_EQ((char*)NULL, mkdtemp(missing_template));
  ASSERT_EQ(EINVAL, errno);
  ASSERT_EQ((char*)NULL, mkdtemp(short_template_XXX));
  ASSERT_EQ(EINVAL, errno);
  ASSERT_EQ((char*)NULL, mkdtemp(not_XXXXXX_suffix));
  ASSERT_EQ(EINVAL, errno);

}

TEST(TestMktemp, mkdtemp) {
  char tempdir[] = "tempfile_XXXXXX";
  ASSERT_NE((char*)NULL, mkdtemp(tempdir));
  // Check that tempname starts with the correct prefix but has been
  // modified from the original.
  ASSERT_EQ(0, strncmp("tempfile_", tempdir, strlen("tempfile_")));
  ASSERT_NE(0, strcmp("tempfile_XXXXXX", tempdir));

  // Check the directory exists
  struct stat buf;
  ASSERT_EQ(0, stat(tempdir, &buf));
  ASSERT_TRUE(S_ISDIR(buf.st_mode));
  ASSERT_EQ(0, rmdir(tempdir));
}

TEST(TestMktemp, mkstemp) {
  char tempfile[] = "tempfile_XXXXXX";
  int fd = mkstemp(tempfile);
  ASSERT_GT(fd, -1);

  // Check that tempname starts with the correct prefix but has been
  // modified from the original.
  ASSERT_EQ(0, strncmp("tempfile_", tempfile, strlen("tempfile_")));
  ASSERT_NE(0, strcmp("tempfile_XXXXXX", tempfile));

  ASSERT_EQ(4, write(fd, "test", 4));
  ASSERT_EQ(0, close(fd));
}

int main(int argc, char** argv) {
  setenv("TERM", "xterm-256color", 0);
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
