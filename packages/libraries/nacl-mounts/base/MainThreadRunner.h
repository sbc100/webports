/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_MAINTHREADRUNNER_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_MAINTHREADRUNNER_H_

#include <pthread.h>
#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/completion_callback.h>
#include <ppapi/cpp/url_loader.h>
#include <ppapi/cpp/url_request_info.h>
#include <ppapi/cpp/url_response_info.h>
#include <ppapi/cpp/var.h>
#include <ppapi/c/pp_errors.h>
#include <semaphore.h>
#include <list>

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

 private:
  static void DoWorkShim(void *p, int32_t unused);
  void DoWork(void);

  pthread_mutex_t lock_;
  std::list<JobEntry*> job_queue_;
  pp::Instance *pepper_instance_;
};

class MainThreadJob {
 public:
  virtual ~MainThreadJob() {}
  virtual void Run(MainThreadRunner::JobEntry *entry) = 0;
};

// MainThreadRunner executes MainThreadJobs asynchronously

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_MAINTHREADRUNNER_H_
