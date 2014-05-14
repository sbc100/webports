/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef GLIBCEMU_FCNTL_H
#define GLIBCEMU_FCNTL_H 1

#include_next <fcntl.h>

#define FIONBIO O_NONBLOCK

#endif  /* GLIBCEMU_FCNTL_H */
