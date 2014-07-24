/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef GLIBCEMU_SYS_FCNTL_H
#define GLIBCEMU_SYS_FCNTL_H 1

#include_next <sys/fcntl.h>

#define FIONBIO O_NONBLOCK
#define creat(pathname, mode) open(pathname, O_CREAT|O_WRONLY|O_TRUNC, mode)

#endif  /* GLIBCEMU_SYS_FCNTL_H */
