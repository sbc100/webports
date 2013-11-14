/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_PTHREAD_HELPERS_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_PTHREAD_HELPERS_H_

#include <assert.h>
#include <pthread.h>
#include <stdint.h>

// A macro to disallow the evil copy constructor and operator= functions
// This should be used in the private: declarations for a class
#define DISALLOW_COPY_AND_ASSIGN(TypeName)      \
  TypeName(const TypeName&);                    \
  void operator=(const TypeName&)

// A macro to disallow all the implicit constructors, namely the
// default constructor, copy constructor and operator= functions.
//
// This should be used in the private: declarations for a class
// that wants to prevent anyone from instantiating it. This is
// especially useful for classes containing only static methods.
#define DISALLOW_IMPLICIT_CONSTRUCTORS(TypeName) \
  TypeName();                                    \
  DISALLOW_COPY_AND_ASSIGN(TypeName)

class Mutex {
 public:
  Mutex() {
    pthread_mutexattr_t attrs;
    int result = pthread_mutexattr_init(&attrs);
    assert(result == 0);
    result = pthread_mutexattr_settype(&attrs, PTHREAD_MUTEX_RECURSIVE);
    assert(result == 0);
    result = pthread_mutex_init(&mutex_, &attrs);
    assert(result == 0);
    pthread_mutexattr_destroy(&attrs);
  }

  ~Mutex() {
     pthread_mutex_destroy(&mutex_);
  }

  pthread_mutex_t* get() {
    return &mutex_;
  }

 private:
  pthread_mutex_t mutex_;
  DISALLOW_COPY_AND_ASSIGN(Mutex);
};

class SimpleAutoLock {
 public:
  explicit SimpleAutoLock(pthread_mutex_t *lock) {
    lock_ = lock;
    pthread_mutex_lock(lock_);
  }
  explicit SimpleAutoLock(Mutex& lock) {
    lock_ = lock.get();
    pthread_mutex_lock(lock_);
  }
  ~SimpleAutoLock() {
    pthread_mutex_unlock(lock_);
  }
  pthread_mutex_t* get() {
    return lock_;
  }
 private:
  pthread_mutex_t *lock_;
};

class Cond {
 public:
  Cond() {
    pthread_cond_init(&cond_, NULL);
  }

  ~Cond() {
    pthread_cond_destroy(&cond_);
  }

  pthread_cond_t* get() {
    return &cond_;
  }

  void broadcast() {
    pthread_cond_broadcast(&cond_);
  }

  void signal() {
    pthread_cond_signal(&cond_);
  }

  int wait(Mutex& lock) {
    return pthread_cond_wait(&cond_, lock.get());
  }

  int timedwait(Mutex& lock, const timespec* abstime) {
    return pthread_cond_timedwait(&cond_, lock.get(), abstime);
  }

 private:
  mutable pthread_cond_t cond_;
  DISALLOW_COPY_AND_ASSIGN(Cond);
};

class ThreadSafeRefCount {
 public:
  ThreadSafeRefCount()
      : ref_(0) {
  }

  int32_t AddRef() {
    __sync_fetch_and_add(&ref_, 1);
    return ref_;
  }

  int32_t Release() {
    __sync_fetch_and_sub(&ref_, 1);
    return ref_;
  }

 private:
  int32_t ref_;
  DISALLOW_COPY_AND_ASSIGN(ThreadSafeRefCount);
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_PTHREAD_HELPERS_H_

