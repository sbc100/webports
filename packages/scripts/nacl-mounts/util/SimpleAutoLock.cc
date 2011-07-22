/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include "SimpleAutoLock.h"

SimpleAutoLock::SimpleAutoLock(pthread_mutex_t *lock) {
  lock_ = lock;
  pthread_mutex_lock(lock_);
}

SimpleAutoLock::~SimpleAutoLock() {
  pthread_mutex_unlock(lock_);
}
