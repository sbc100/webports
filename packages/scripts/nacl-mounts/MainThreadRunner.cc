/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include "MainThreadRunner.h"

// kWORK_POLL_TIMEOUT sets the time delay (in milliseconds) between checks
// for available jobs.
static const int kWORK_POLL_TIMEOUT = 10;

struct MainThreadJobEntry {
  pp::Instance *pepper_instance;
  MainThreadRunner *runner;
  MainThreadJob *job;
  sem_t done;
  int32_t result;
};

MainThreadRunner::MainThreadRunner(pp::Instance *instance) {
  pepper_instance_ = instance;
  DoWork();
  pthread_mutex_init(&lock_, NULL);
}

MainThreadRunner::~MainThreadRunner() {
  pthread_mutex_destroy(&lock_);
}

int32_t MainThreadRunner::RunJob(MainThreadJob* job) {
  MainThreadJobEntry entry;

  // initialize the entry
  entry.runner = this;
  entry.pepper_instance = pepper_instance_;
  entry.job = job;
  sem_init(&entry.done, 0, 0);

  // put the job on the queue
  pthread_mutex_lock(&lock_);
  job_queue_.push_back(&entry);
  pthread_mutex_unlock(&lock_);

  // wait until the job is done
  sem_wait(&entry.done);
  sem_destroy(&entry.done);
  return entry.result;
}

void MainThreadRunner::ResultCompletion(void *arg, int32_t result) {
  MainThreadJobEntry *entry = reinterpret_cast<MainThreadJobEntry*>(arg);
  entry->result = result;
  DoWorkShim(entry->runner, 0);
  sem_post(&entry->done);
}

void MainThreadRunner::DoWorkShim(void *p, int32_t unused) {
  MainThreadRunner *mtr = static_cast<MainThreadRunner *>(p);
  mtr->DoWork();
}

void MainThreadRunner::DoWork(void) {
  pthread_mutex_lock(&lock_);
  if (!job_queue_.empty()) {
    MainThreadJobEntry *entry = job_queue_.front();
    job_queue_.pop_front();
    entry->job->Run(entry);
  } else {
    pp::Module::Get()->core()->CallOnMainThread(kWORK_POLL_TIMEOUT,
        pp::CompletionCallback(&DoWorkShim, this), PP_OK);
  }
  pthread_mutex_unlock(&lock_);
}

