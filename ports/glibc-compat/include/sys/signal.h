/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef GLIBCEMU_SYS_SIGNAL_H
#define GLIBCEMU_SYS_SIGNAL_H

#include_next <sys/signal.h>

#define SA_RESTART 0x10000000

struct sigvec {
  void (*sv_handler)();
  int sv_mask;
  int sv_flags;
};

#endif
