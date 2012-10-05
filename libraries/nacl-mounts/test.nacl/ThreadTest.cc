/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include "gtest/gtest.h"
#include "base/MainThreadRunner.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

static int wake_count;
static pthread_mutex_t run_count_lock;
static int run_count;

class MainThreadRunnerTested : public MainThreadRunner {
 public:
  MainThreadRunnerTested() : MainThreadRunner(0) {
  }

 private:
  void WakePepperThread(void) {
    ++wake_count;
  }
};

class TestJob : public MainThreadJob {
 public:
  void Run(MainThreadRunner::JobEntry *e) {
    pthread_mutex_lock(&run_count_lock);
    ++run_count;
    pthread_mutex_unlock(&run_count_lock);
    MainThreadRunner::ResultCompletion(e, 123);
  }
};

static void *my_thread(void *arg) {
  MainThreadRunner *mtr = static_cast<MainThreadRunner*>(arg);
  EXPECT_EQ(123, mtr->RunJob(new TestJob));
  return 0;
}

TEST(ThreadTest, WakeTest) {
  MainThreadRunner *mtr = new MainThreadRunnerTested;
  wake_count = 0;
  run_count = 0;
  pthread_mutex_init(&run_count_lock, NULL);
  pthread_t tid;
  for (int i = 1; i <= 10; ++i) {
    pthread_create(&tid, NULL, my_thread, mtr);
    while (!mtr->DoWork()) {
      // wait for work to be done.
    }
    void *ret;
    pthread_join(tid, &ret);
    EXPECT_EQ(NULL, ret);
    // Require one wakeup per request.
    EXPECT_EQ(i, wake_count);
    // Require one run per request.
    EXPECT_EQ(i, run_count);
  }
  pthread_mutex_destroy(&run_count_lock);
}

TEST(ThreadTest, Wake3Test) {
  MainThreadRunner *mtr = new MainThreadRunnerTested;
  wake_count = 0;
  run_count = 0;
  pthread_mutex_init(&run_count_lock, NULL);
  pthread_t tid1, tid2, tid3;
  for (int i = 1; i <= 10; ++i) {
    pthread_create(&tid1, NULL, my_thread, mtr);
    pthread_create(&tid2, NULL, my_thread, mtr);
    pthread_create(&tid3, NULL, my_thread, mtr);
    while (mtr->PendingJobs() < 3) {
      // wait for jobs to be pending.
    }
    EXPECT_EQ(i, wake_count);
    EXPECT_EQ(3, mtr->PendingJobs());
    while (!mtr->DoWork()) {
      // wait for work to be done.
    }
    void *ret;
    pthread_join(tid1, &ret);
    EXPECT_EQ(NULL, ret);
    pthread_join(tid2, &ret);
    EXPECT_EQ(NULL, ret);
    pthread_join(tid3, &ret);
    EXPECT_EQ(NULL, ret);
    // Require only one new wakeup for the two requests.
    EXPECT_EQ(i, wake_count);
    // Require two runs.
    EXPECT_EQ(i * 3, run_count);
  }
}
