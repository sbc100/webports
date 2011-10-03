/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <pthread.h>
#include <stdio.h>
#include "base/MainThreadRunner.h"
#include "gtest/gtest.h"


// Number of times to block in thread tests.
static const int kTimesToBlock = 10;


// Fake pointer to a pepper instance (never dereferenced).
static pp::Instance* kBogusPepperInstance =
    reinterpret_cast<pp::Instance*>(0x12345678);


struct MainThreadCounter {
  int counter;
  MainThreadRunner* runner;

  MainThreadCounter() {
    counter = 0;
  }
};


class IncrementCounter : public MainThreadJob {
 public:
  explicit IncrementCounter(MainThreadCounter* counter) {
    counter_ = counter;
  }

  virtual void Run(MainThreadRunner::JobEntry* entry) {
    EXPECT_TRUE(MainThreadRunner::ExtractPepperInstance(entry) ==
                kBogusPepperInstance);
    EXPECT_TRUE(MainThreadRunner::IsMainThread());
    EXPECT_TRUE(!MainThreadRunner::IsPseudoThread());
    ++counter_->counter;
    MainThreadRunner::ResultCompletion(entry, counter_->counter);
  }

 private:
  MainThreadCounter* counter_;
};


static void *Secondary(void *arg) {
  MainThreadCounter* counter = reinterpret_cast<MainThreadCounter*>(arg);

  for (int i = 0; i < kTimesToBlock; ++i) {
    EXPECT_TRUE(!MainThreadRunner::IsMainThread() ||
                MainThreadRunner::IsPseudoThread());
    IncrementCounter* job = new IncrementCounter(counter);
    int32_t ret = counter->runner->RunJob(job);
    EXPECT_TRUE(ret == i + 1);
    EXPECT_TRUE(!MainThreadRunner::IsMainThread() ||
                MainThreadRunner::IsPseudoThread());
  }
  return 0;
}


TEST(MainThreadRunnerTest, NormalThreads) {
  MainThreadRunner* runner = new MainThreadRunner(kBogusPepperInstance);
  EXPECT_EQ(true, MainThreadRunner::IsMainThread());
  MainThreadCounter counter;
  counter.runner = runner;
  pthread_t main_thread_id;
  EXPECT_EQ(0, pthread_create(&main_thread_id, 0, Secondary, &counter));
  while (counter.counter < kTimesToBlock) {
    runner->DoWork();
  }
  pthread_join(main_thread_id, NULL);
  EXPECT_EQ(kTimesToBlock, counter.counter);
}


TEST(MainThreadRunnerTest, PseudoThreads) {
  MainThreadRunner* runner = new MainThreadRunner(kBogusPepperInstance);
  EXPECT_EQ(true, MainThreadRunner::IsMainThread());
  MainThreadCounter counter;
  counter.runner = runner;
  runner->PseudoThreadFork(Secondary, &counter);
  while (counter.counter < kTimesToBlock) {
    EXPECT_EQ(false, MainThreadRunner::IsPseudoThread());
    runner->DoWork();
  }
  EXPECT_EQ(kTimesToBlock, counter.counter);
}
