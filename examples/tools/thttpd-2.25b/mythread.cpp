/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "mythread.h"
#include <nacl-mounts/util/DebugPrint.h>
#include <cstdio>

/* Returns true if the thread was successfully started,
 * false if there was an error starting the thread */
bool MyThreadClass::StartInternalThread() {
  int r = pthread_create(&_thread, NULL, InternalThreadEntryFunc, this);
  if (r != 0) {
    dbgprintf("could not start internal thread\n");
  }
  return r;
}

/** Will not return until the internal thread has exited. */
void MyThreadClass::WaitForInternalThreadToExit() {
  (void) pthread_join(_thread, NULL);
}

void* MyThreadClass::InternalThreadEntryFunc(void* This) {
  reinterpret_cast<MyThreadClass*>(This)->InternalThreadEntry();
  return NULL;
}

