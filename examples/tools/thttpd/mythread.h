/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifndef __MYTHREAD_H__
#define __MYTHREAD_H__

#include <pthread.h>

class MyThreadClass {
 public:
  MyThreadClass() {/* empty */}
  virtual ~MyThreadClass() {/* empty */}

  /* Returns true if the thread was successfully started,
   * false if there was an error starting the thread */
  bool StartInternalThread();

  /** Will not return until the internal thread has exited. */
  void WaitForInternalThreadToExit();

 protected:
  /* Implement this method in your subclass with the code
   * you want your thread to run. */
  virtual void InternalThreadEntry() = 0;

 private:
  static void * InternalThreadEntryFunc(void * This);

  pthread_t _thread;
};

#endif

