/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef LIBRARIES_NACL_MOUNTS_BASE_MAINTHREADRUNNER_H_
#define LIBRARIES_NACL_MOUNTS_BASE_MAINTHREADRUNNER_H_

#include <pthread.h>
#include <semaphore.h>
#include <setjmp.h>
#include <list>

// Keep pepper specifics out so we can unit test.
namespace pp {
  class Instance;
};

// MainThreadJob is a class that provides a method for running
// a MainThreadRunner::JobEntry.
class MainThreadJob;

// MainThreadRunner executes MainThreadJobs asynchronously
// on the main thread.
class MainThreadRunner {
 public:
  explicit MainThreadRunner(pp::Instance *instance);
  ~MainThreadRunner();

  // RunJob() creates an entry for the job and submits
  // that job for execution.
  int32_t RunJob(MainThreadJob *job);

  // ResultCompletion() is a function for putting result into arg, which
  // is reinterpreted as a JobEntry pointer.  ResultCompletion()
  // is intended to be used with pp::CompletionCallback()
  static void ResultCompletion(void *arg, int32_t result);

  // The JobEntry struct provides all of the information for
  // a particular job.  It acts as an opaque handle to the job to and
  // is used by ResultCompletion().
  struct JobEntry;

  static pp::Instance *ExtractPepperInstance(MainThreadRunner::JobEntry *e);

  // You can have one 'pseudothread' on top of the main thread.
  // This coroutine (setjmp) based thread can block on Run.
  // You will have to take some amount of re-entrancy into account.
  // Assumes 640K of stack is enough for anyone for event handling in the
  // main thread.
  static void PseudoThreadFork(void *(*func)(void *arg), void *arg);
  // Same as above with selectable bytes of headroom.
  static void PseudoThreadHeadroomFork(
      int bytes_headroom, void *(*func)(void *arg), void *arg);

  // Returns:
  //   true - main thread or pseudothread.
  //   false - other pthreads.
  static bool IsMainThread(void);

  // Returns true if on the psuedothread.
  static bool IsPseudoThread(void);

  // Use these directly only if you are interacting with PPAPI
  // such that you can guarantee you'll resume because of an
  // asynchronous event you issued.
  // Block pseudothread until main thread yields.
  static void PseudoThreadBlock(void);
  // Yield main thread to pseudothread.
  static void PseudoThreadResume(void);

  // Do at least one main thread job.
  // DO NOT use this with pepper (which sets up an event
  // cycle to call this automatically).
  // Use directly only for testing.
  void DoWork(void);

 private:
  static void DoWorkShim(void *p, int32_t unused);

  // Used to keep things above the headroom.
  static void InnerPseudoThreadFork(void *(func)(void *arg), void *arg);

  pthread_mutex_t lock_;
  std::list<JobEntry*> job_queue_;
  pp::Instance *pepper_instance_;

  static jmp_buf pseudo_thread_state_;
  static jmp_buf main_thread_state_;
  static bool in_pseudo_thread_;
  static bool forked_pseudo_thread_;
};

class MainThreadJob {
 public:
  virtual ~MainThreadJob() {}
  virtual void Run(MainThreadRunner::JobEntry *entry) = 0;
};

// MainThreadRunner executes MainThreadJobs asynchronously

#endif  // LIBRARIES_NACL_MOUNTS_BASE_MAINTHREADRUNNER_H_
