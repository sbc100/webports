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
  is_dir_ = false;
  is_dir_known_ = false;
  capacity_ = 0;
  data_ = NULL;
}

void AppEngineNode::ReallocData(int len) {
  assert(len > 0);
  // TODO(arbenson): Handle memory overflow more gracefully.
  data_ = reinterpret_cast<char *>(realloc(data_, len));
  assert(data_);
  capacity_ = len;
}

int AppEngineNode::WriteData(off_t offset, const void *buf, size_t count) {
  // Grow the file if needed.
  size_t len = capacity_;
  if (offset + static_cast<off_t>(count) > static_cast<off_t>(len)) {
    len = offset + count;
    size_t next = (capacity_ + 1) * 2;
    if (next > len) {
      len = next;
    }
    ReallocData(len);
  }
  // Pad any gap with zeros.
  // TODO(arbenson): double check this logic
  if (offset > static_cast<off_t>(len_)) {
    memset(data_+len, 0, offset);
  }
  memcpy(data_ + offset, buf, count);
  offset += count;
  if (offset > static_cast<off_t>(len_)) {
    len_ = offset;
  }
  is_dirty_ = true;
  return count;
}

char *AppEngineNode::data(void) {
  return data_;
}
