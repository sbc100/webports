/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "AppEngineNode.h"
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

AppEngineNode::AppEngineNode() {
  len_ = 0;
  use_count_ = 0;
  is_dirty_ = false;
}

void AppEngineNode::ReallocData(int len) {
  assert(len > 0);
  data_.resize(len);
}

int AppEngineNode::WriteData(off_t offset, const void *buf, size_t count) {
  size_t len;
  // Grow the file if needed.
  if (offset + static_cast<off_t>(count) > data_.size()) {
    len = offset + count;
    size_t next = (data_.size() + 1) * 2;
    if (next > len) {
      len = next;
    }
    ReallocData(len);
  }
  memcpy(&data_[0] + offset, buf, count);
  len_ = offset + count;
  is_dirty_ = true;
  return 0;
}

char *AppEngineNode::data(void) {
  if (data_.empty()) {
    return NULL;
  }
  return &data_[0];
}
