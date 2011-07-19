/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_SCRIPTS_NACL_MOUNTS_SIMPLEAUTOLOCK_H_
#define PACKAGES_SCRIPTS_NACL_MOUNTS_SIMPLEAUTOLOCK_H_

#include <pthread.h>

class SimpleAutoLock {
 public:
  explicit SimpleAutoLock(pthread_mutex_t *lock);
  ~SimpleAutoLock();

 private:
  pthread_mutex_t *lock_;
};

#endif  // PACKAGES_SCRIPTS_NACL_MOUNTS_SIMPLEAUTOLOCK_H_
