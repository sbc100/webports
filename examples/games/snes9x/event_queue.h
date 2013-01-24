/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifndef __EVENT_QUEUE_H__
#define __EVENT_QUEUE_H__

#include <string>
#include "pthread.h"

#define NaClLog(lev, ...)  fprintf(stderr, __VA_ARGS__)
#define kMaxSize 1024

using std::string;

struct Event {
  Event(const string &a, const string &k, bool s = false) {
    act = a;
    key = k;
    shift = s;
  }

  string act;
  string key;
  bool shift;
};

class EventQueue {
 public:
  EventQueue() {
    pthread_mutex_init(&mutex, NULL);
    pthread_cond_init(&condvar, NULL);
  }

  void push(Event* event) {
    pthread_mutex_lock(&mutex);
    if (num >= kMaxSize) {
      NaClLog(LOG_ERROR, "dropping event because of overflow\n");
    } else {
      int head = (tail + num) % kMaxSize;
      queue[head] = event;
      ++num;
      if (num >= kMaxSize) num -= kMaxSize;
      pthread_cond_signal(&condvar);
    }

    pthread_mutex_unlock(&mutex);
  }

  Event* dequeue(bool blocking) {
    Event* event = NULL;
    pthread_mutex_lock(&mutex);
    if (num == 0 && blocking) {
      pthread_cond_wait(&condvar, &mutex);
    }

    if (num > 0) {
      event = queue[tail];
      ++tail;
      if (tail >= kMaxSize) tail -= kMaxSize;
      --num;
    }
    pthread_mutex_unlock(&mutex);
    return event;
  }

  size_t size() const {
    return num;
  }

  bool empty() const {
    return num == 0;
  }

 private:
  pthread_mutex_t mutex;
  pthread_cond_t condvar;
  int tail;
  int num;
  Event* queue[kMaxSize];
};

#endif
