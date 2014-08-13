/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef GLIBCEMU_SPAWN_H
#define GLIBCEMU_SPAWN_H

#include_next <spawn.h>
#include <sched.h>

/*
 * Disable a macro added by cdefs.h for backward compatibility.
 */
#if defined(__used)
# undef __used
#endif

/*
 * Mirror glibc structures approximately so we can share code in reading them.
 */
struct __posix_spawn_file_actions {
  int __allocated;
  int __used;
  struct __spawn_action* __actions;
};

struct __posix_spawnattr {
  short int flags;
  pid_t pgroup;
  sigset_t sigdefault;
  sigset_t sigmask;
  struct sched_param schedparam;
  int policy;
};

#endif
