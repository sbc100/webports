/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "JSPipeMount.h"


JSPipeMount::JSPipeMount() : prefix_("JSPipeMount") {
  is_tty_ = 1;
  outbound_bridge_ = NULL;
  int ret = pthread_mutex_init(&incoming_lock_, 0);
  assert(!ret);
  ret = pthread_cond_init(&incoming_available_, 0);
  assert(!ret);
}

JSPipeMount::~JSPipeMount() {
  int ret = pthread_mutex_destroy(&incoming_lock_);
  assert(!ret);
  ret = pthread_cond_destroy(&incoming_available_);
  assert(!ret);
}

int JSPipeMount::Creat(const std::string& path, mode_t mode,
                       struct stat* buf) {
  return GetNode(path, buf);
}

int JSPipeMount::GetNode(const std::string& path, struct stat* buf) {
  int id;

  // Allow non-negative pipe numbers.
  if (sscanf(path.c_str(), "/%d", &id) != 1 && id >= 0) {
    return -1;
  }
  return Stat(id + 1, buf);
}

int JSPipeMount::Stat(ino_t node, struct stat *buf) {
  memset(buf, 0, sizeof(struct stat));
  buf->st_ino = node;
  buf->st_mode = S_IFREG | 0777;
  return 0;
}

ssize_t JSPipeMount::Read(ino_t slot, off_t offset,
                          void *buf, size_t count) {
  if (slot < 0) {
    errno = ENOENT;
    return -1;
  }

  SimpleAutoLock lock(&incoming_lock_);

  // TODO(bradnelson): currently this always blocks if nothing is
  // available. We likely want nacl-mounts to support non-blocking i/o +
  // select + poll, at that point this will need to change.
  for (;;) {
    // Find this pipe.
    std::map<int, std::vector<char> >:: iterator i = incoming_.find(slot - 1);
    if (i == incoming_.end()) {
      pthread_cond_wait(&incoming_available_, &incoming_lock_);
      continue;
    }

    // Limit to the size of the read buffer.
    size_t len = count;
    if (i->second.size() < len) {
      len = i->second.size();
    }

    // Wait for something if empty.
    if (len <= 0) {
      pthread_cond_wait(&incoming_available_, &incoming_lock_);
      continue;
    }

    // Copy out the data.
    memcpy(buf, &i->second[0], len);
    // Remove the data from the buffer.
    i->second.erase(i->second.begin(), i->second.begin() + len);

    return len;
  }
}

ssize_t JSPipeMount::Write(ino_t slot, off_t offset, const void *buf,
                           size_t count) {
  assert(count >= 0);

  if (slot < 1) {
    errno = ENOENT;
    return -1;
  }

  // Allocate a buffer with room for the prefix, the data, and the pipe id.
  char *tmp = new char[count + prefix_.size() + 40];
  memcpy(tmp, prefix_.c_str(), prefix_.size());
  sprintf(tmp + prefix_.size(), ":%d:", static_cast<int>(slot - 1));
  size_t len = prefix_.size() + strlen(tmp + prefix_.size());
  memcpy(tmp + len, buf, count);
  len += count;

  outbound_bridge_->Post(tmp, len);

  delete[] tmp;

  return count;
}

bool JSPipeMount::Receive(const void *buf, size_t count) {
  // Ignore if it doesn't match our prefix.
  if (count < prefix_.size() ||
      memcmp(buf, prefix_.c_str(), prefix_.size()) != 0) {
    return false;
  }

  // Cast buffer to char*, strip off prefix as we don't need it anymore.
  const char *bufc = reinterpret_cast<const char*>(buf) + prefix_.size();
  count -= prefix_.size();

  // Get out the id.
  if (count < 3) { return false; }
  if (*bufc != ':') { return false; }
  ++bufc;  --count;
  char numb[40];
  size_t numb_len = 0;
  while(numb_len < sizeof(numb) - 1 && count > 0 &&
        *bufc != ':' && isdigit(*bufc)) {
    numb[numb_len] = *bufc;
    ++numb_len;
    ++bufc;  --count;
  }
  numb[numb_len] = '\0';
  if (count <= 0) { return false; }
  if (*bufc != ':') { return false; }
  ++bufc;  --count;
  int id;
  if (sscanf(numb, "%d", &id) != 1) { return false; }

  SimpleAutoLock lock(&incoming_lock_);

  // Find that buffer.
  std::map<int, std::vector<char> >:: iterator i = incoming_.find(id);
  if (i == incoming_.end()) {
    incoming_[id] = std::vector<char>();
    i = incoming_.find(id);
    assert(i != incoming_.end());
  }

  // Add it.
  i->second.insert(i->second.end(), bufc, bufc + count);

  // Signal we've got something.
  pthread_cond_broadcast(&incoming_available_);

  return true;
}
