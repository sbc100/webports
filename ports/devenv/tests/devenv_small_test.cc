// Copyright (c) 2014 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "gtest/gtest.h"

#include <spawn.h>
#include <unistd.h>

static char *argv0;

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

// Used in main to allow the test exectuable to be started
// as a subprocess.
// Child takes args:
// ./test return <return-code> <expected-foo-env>
// ./test _exit <return-code> <expected-foo-env>
// It will return 55 as a bad return value in the case
// that the FOO environment variable isn't the expected
// value.
static int handle_child_startup(int argc, char **argv) {
  if (argc == 4) {
    if (strcmp(argv[3], getenv("FOO")) != 0) {
      return 55;
    }
    if (strcmp(argv[1], "return") == 0) {
      return atoi(argv[2]);
    } else if(strcmp(argv[1], "_exit") == 0) {
      _exit(atoi(argv[2]));
    }
  }
  return 0;
}

#define ARGV_FOR_CHILD(x) \
  char *argv[5]; \
  argv[0] = argv0; \
  argv[1] = const_cast<char*>("return"); \
  argv[2] = const_cast<char*>("111"); \
  argv[3] = const_cast<char*>(x); \
  argv[4] = NULL;

#define ENVP_FOR_CHILD(x) \
  char *envp[2]; \
  envp[0] = const_cast<char*>(x); \
  envp[1] = NULL;

TEST(Spawn, spawnve) {
  int status;
  ARGV_FOR_CHILD("spawnve");
  ENVP_FOR_CHILD("FOO=spawnve");
  pid_t pid = spawnve(P_NOWAIT, argv0, argv, envp);
  ASSERT_GE(pid, 0);
  pid_t npid = waitpid(pid, &status, 0);
  EXPECT_EQ(pid, npid);
  EXPECT_TRUE(WIFEXITED(status));
  EXPECT_EQ(111, WEXITSTATUS(status));
}

#define VFORK_SETUP_SPAWN \
  int status; \
  pid_t pid = vfork(); \
  ASSERT_GE(pid, 0); \
  if (pid) { \
    pid_t npid = waitpid(pid, &status, 0); \
    EXPECT_EQ(pid, npid); \
    EXPECT_TRUE(WIFEXITED(status)); \
    EXPECT_EQ(111, WEXITSTATUS(status)); \
  } else

TEST(Vfork, execve) {
  VFORK_SETUP_SPAWN {
    ARGV_FOR_CHILD("execve");
    ENVP_FOR_CHILD("FOO=execve");
    execve(argv0, argv, envp);
  }
}

TEST(Vfork, execv) {
  setenv("FOO", "execv", 1);
  VFORK_SETUP_SPAWN {
    ARGV_FOR_CHILD("execv");
    execv(argv0, argv);
  }
}

TEST(Vfork, execvp) {
  setenv("FOO", "execvp", 1);
  VFORK_SETUP_SPAWN {
    ARGV_FOR_CHILD("execvp");
    execvp(argv0, argv);
  }
}

TEST(Vfork, execvpe) {
  VFORK_SETUP_SPAWN {
    ARGV_FOR_CHILD("execvpe");
    ENVP_FOR_CHILD("FOO=execvpe");
    execvpe(argv0, argv, envp);
  }
}

TEST(Vfork, execl) {
  setenv("FOO", "execl", 1);
  VFORK_SETUP_SPAWN {
    execl(argv0, argv0, "return", "111", "execl", NULL);
  }
}

TEST(Vfork, execlp) {
  setenv("FOO", "execlp", 1);
  VFORK_SETUP_SPAWN {
    execlp(argv0, argv0, "return", "111", "execlp", NULL);
  }
}

TEST(Vfork, execle) {
  VFORK_SETUP_SPAWN {
    ENVP_FOR_CHILD("FOO=execle");
    execle(argv0, argv0, "return", "111", "execle", NULL, envp);
  }
}

TEST(Vfork, execlpe) {
  VFORK_SETUP_SPAWN {
    ENVP_FOR_CHILD("FOO=execlpe");
    execlpe(argv0, argv0, "return", "111", "execlpe", NULL, envp);
  }
}

TEST(Vfork, exit) {
  int status;
  pid_t pid = vfork();
  ASSERT_GE(pid, 0);
  if (pid) {
    pid_t npid = waitpid(pid, &status, 0);
    EXPECT_EQ(pid, npid);
    EXPECT_TRUE(WIFEXITED(status));
    EXPECT_EQ(123, WEXITSTATUS(status));
  } else {
    _exit(123);
  }
}

TEST(Vfork, RegularExit) {
  VFORK_SETUP_SPAWN {
    ENVP_FOR_CHILD("FOO=RegularExit");
    execlpe(argv0, argv0, "_exit", "111", "RegularExit", NULL, envp);
  }
}


extern "C" int nacl_main(int argc, char **argv) {
  int ret = handle_child_startup(argc, argv);
  if (ret)
    return ret;
  // Preserve argv[0] for use in some tests.
  argv0 = argv[0];
  testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
