/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include "base/MainThreadRunner.h"
#include <alloca.h>
#include <assert.h>
#include <errno.h>

// Only use pepper in nacl to allow unit testing.
#ifdef __native_client__
#  include <ppapi/c/pp_errors.h>
#  include <ppapi/cpp/completion_callback.h>
#  include <ppapi/cpp/module.h>
#  define USE_PEPPER
#endif

// Stack space to allocate by default to the event handler
// thread in the presence of an ancillary 'pseudo-thread'.
// 640K of stack should be enough for anyone.
static const int kDefaultPseudoThreadHeadroom = 640 * 1024;

// If we're not using pepper, track main thread's id so
// we can do something sensible.
#ifndef USE_PEPPER
static pthread_t main_thread_id_;
#endif

struct MainThreadRunner::JobEntry {
  pp::Instance* pepper_instance;
  MainThreadRunner* runner;
  MainThreadJob* job;
  pthread_mutex_t done_mutex;
  pthread_cond_t done_cond;
  bool is_done;
  int32_t result;
  bool pseudo_thread_job;
  bool async_job;
};


MainThreadRunner::MainThreadRunner(pp::Instance *instance) {
#ifndef USE_PEPPER
  // Record main thread if not using pepper.
  main_thread_id_ = pthread_self();
#endif

  pepper_instance_ = instance;
  pthread_mutex_init(&lock_, NULL);
}

MainThreadRunner::~MainThreadRunner() {
  pthread_mutex_destroy(&lock_);
}

int32_t MainThreadRunner::RunJob(MainThreadJob* job) {
  JobEntry entry;

  // initialize the entry
  entry.runner = this;
  entry.pepper_instance = pepper_instance_;
  entry.job = job;
  entry.async_job = false;

  bool in_main_thread = IsMainThread();
  // Must be off main thread, or on a pseudothread.
  assert(!in_main_thread || in_pseudo_thread_);

  // Thread type specific initialization.
  if (in_main_thread) {
    entry.pseudo_thread_job = true;
  } else {
    entry.pseudo_thread_job = false;
    // Init condition variable.
    entry.is_done = false;
    int ret = pthread_mutex_init(&entry.done_mutex, NULL);
    assert(!ret);
    ret = pthread_cond_init(&entry.done_cond, NULL);
    assert(!ret);
  }

  // put the job on the queue
  pthread_mutex_lock(&lock_);
#ifdef USE_PEPPER
  // Only schedule a wakeup if nothing else has.
  if (job_queue_.empty()) {
    // Schedule a wakeup.
    pp::Module::Get()->core()->CallOnMainThread(0,
        pp::CompletionCallback(&DoWorkShim, this), PP_OK);
  }
#endif
  job_queue_.push_back(&entry);
  pthread_mutex_unlock(&lock_);

  // Block differntly on the main thread.
  if (entry.pseudo_thread_job) {
    // block pseudothread until job is done
    PseudoThreadBlock();
  } else {
    // wait on condition until the job is done
    pthread_mutex_lock(&entry.done_mutex);
    while (!entry.is_done) {
      pthread_cond_wait(&entry.done_cond, &entry.done_mutex);
    }
    pthread_mutex_unlock(&entry.done_mutex);
    pthread_mutex_destroy(&entry.done_mutex);
    pthread_cond_destroy(&entry.done_cond);
  }

  // Cleanup.
  delete job;
  return entry.result;
}

void MainThreadRunner::RunJobAsync(MainThreadJob* job) {
  JobEntry *entry = new JobEntry;

  // initialize the entry
  entry->runner = this;
  entry->pepper_instance = pepper_instance_;
  entry->job = job;
  entry->async_job = true;

  bool in_main_thread = IsMainThread();
  // Must be off main thread, or on a pseudothread.
  assert(!in_main_thread || in_pseudo_thread_);

  // put the job on the queue
  pthread_mutex_lock(&lock_);
#ifdef USE_PEPPER
  // Only schedule a wakeup if nothing else has.
  if (job_queue_.empty()) {
    // Schedule a wakeup.
    pp::Module::Get()->core()->CallOnMainThread(0,
        pp::CompletionCallback(&DoWorkShim, this), PP_OK);
  }
#endif
  job_queue_.push_back(entry);
  pthread_mutex_unlock(&lock_);
}

void MainThreadRunner::ResultCompletion(void *arg, int32_t result) {
  JobEntry* entry = reinterpret_cast<JobEntry*>(arg);
#ifdef USE_PEPPER
  // Grab this here because entry will be invalid later.
  MainThreadRunner* runner = entry->runner;
#endif
  entry->result = result;
  // Handle async differently.
  if (entry->async_job) {
    // Cleanup happens on the main thread for async.
    delete entry->job;
    delete entry;
  } else {
    // Signal differently depending on if the pseudothread is involved.
    if (entry->pseudo_thread_job) {
      PseudoThreadResume();
    } else {
      pthread_mutex_lock(&entry->done_mutex);
      entry->is_done = true;
      pthread_cond_signal(&entry->done_cond);
      pthread_mutex_unlock(&entry->done_mutex);
    }
  }
#ifdef USE_PEPPER
  // Do more work now if in pepper.
  DoWorkShim(runner, 0);
#endif
}

void MainThreadRunner::DoWorkShim(void *p, int32_t unused) {
  MainThreadRunner* mtr = static_cast<MainThreadRunner *>(p);
  mtr->DoWork();
}

void MainThreadRunner::DoWork(void) {
  pthread_mutex_lock(&lock_);
  while (!job_queue_.empty()) {
    JobEntry* entry = job_queue_.front();
    job_queue_.pop_front();
    pthread_mutex_unlock(&lock_);
    entry->job->Run(entry);
    pthread_mutex_lock(&lock_);
  }
  pthread_mutex_unlock(&lock_);
}

pp::Instance *MainThreadRunner::ExtractPepperInstance(
    MainThreadRunner::JobEntry *e) {
  return e->pepper_instance;
}

void MainThreadRunner::PseudoThreadFork(void *(*func)(void *arg), void *arg) {
  PseudoThreadHeadroomFork(kDefaultPseudoThreadHeadroom, func, arg);
}

void MainThreadRunner::PseudoThreadHeadroomFork(
    int bytes_headroom, void *(*func)(void *arg), void *arg) {
  // Must be run from the main thread.
  assert(IsMainThread());
  // Only one pseudothread can be forked.
  assert(!forked_pseudo_thread_);
  // Leave a gap of bytes_headroom on the stack between
  alloca(bytes_headroom);
  // Goto pseudothread, but remeber how to come back here.
  if (!setjmp(main_thread_state_)) {
    InnerPseudoThreadFork(func, arg);
  }
  in_pseudo_thread_ = false;
}

// Put things in another scope to keep above headroom,
// even after thread ends.
void MainThreadRunner::InnerPseudoThreadFork(
    void *(func)(void *arg), void *arg) {
  forked_pseudo_thread_ = true;
  in_pseudo_thread_ = true;
  func(arg);
  forked_pseudo_thread_ = false;
  in_pseudo_thread_ = false;
  // Dead, keep kicking back to the main thread.
  for (;;) {
    longjmp(main_thread_state_, 1);
  }
}

void MainThreadRunner::PseudoThreadBlock(void) {
  // Must be run from the main thread.
  assert(IsMainThread());
  // Pseudothread must have been forked.
  assert(forked_pseudo_thread_);
  // Must be run only from the pseudothread.
  assert(in_pseudo_thread_);
  if (!setjmp(pseudo_thread_state_)) {
    // Go back to the main thread after saving state.
    longjmp(main_thread_state_, 1);
  }
  in_pseudo_thread_ = true;
}

void MainThreadRunner::PseudoThreadResume(void) {
  // Must be run from the main thread.
  assert(IsMainThread());
  // Pseudothread must have been forked.
  assert(forked_pseudo_thread_);
  // Can only be run from the main thread.
  assert(!in_pseudo_thread_);
  if (!setjmp(main_thread_state_)) {
    // Go back to the pseudo thread after saving state.
    longjmp(pseudo_thread_state_, 1);
  }
  in_pseudo_thread_ = false;
}

bool MainThreadRunner::IsMainThread(void) {
#ifdef USE_PEPPER
  return pp::Module::Get()->core()->IsMainThread();
#else
  return pthread_equal(pthread_self(), main_thread_id_);
#endif
}

bool MainThreadRunner::IsPseudoThread(void) {
  return IsMainThread() && in_pseudo_thread_;
}

// Static variables in MainThreaadRunner.
jmp_buf MainThreadRunner::main_thread_state_;
jmp_buf MainThreadRunner::pseudo_thread_state_;
bool MainThreadRunner::in_pseudo_thread_ = false;
bool MainThreadRunner::forked_pseudo_thread_ = false;
