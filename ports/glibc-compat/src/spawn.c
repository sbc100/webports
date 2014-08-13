/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <spawn.h>
#include <stdlib.h>
#include <string.h>

/*
 * Mirror the layout of the glibc structure so we can access this from
 * nacl-spawn.
 */
struct __spawn_action {
  enum {
    SPAWN_DO_CLOSE,
    SPAWN_DO_DUP2,
    SPAWN_DO_OPEN
  } tag;
  union {
    struct {
      int fd;
    } close_action;
    struct {
      int fd;
      int newfd;
    } dup2_action;
    struct {
      int fd;
      const char* path;
      int oflag;
      mode_t mode;
    } open_action;
  } action;
};

int posix_spawn_file_actions_init(
    posix_spawn_file_actions_t* file_actions) {
  memset(file_actions, 0, sizeof(*file_actions));
  return 0;
}

int posix_spawn_file_actions_destroy(
    posix_spawn_file_actions_t* file_actions) {
  free(file_actions->__actions);
  return 0;
}

static int posix_spawn_file_actions_grow(
    posix_spawn_file_actions* file_actions) {
  if (file_actions->__used < file_actions->__allocated) {
    return 0;
  }
  void* n = realloc(
      file_actions->__actions,
      sizeof(*file_actions->__actions) * (file_actions->__allocated + 8));
  if (!n) {
    return -1;
  }
  file_actions->__actions = static_cast<struct __spawn_actions *>(n);
  return 0;
}

int posix_spawn_file_actions_addopen(
    posix_spawn_file_actions_t* file_actions, int fildes,
    const char* path, int oflag, mode_t mode) {
  if (posix_spawn_file_actions_grow(file_actions)) {
    return ENOMEM;
  }
  struct __spawn_action* action =
      file_actions->__actions[file_actions->__used++];
  action->tag = SPAWN_DO_OPEN;
  action->action.open_action.fd = fildes;
  action->action.open_action.path = path;
  action->action.open_action.oflag = oflag;
  action->action.open_action.mode = mode;
  return 0;
}

int posix_spawn_file_actions_adddup2(
    posix_spawn_file_actions_t *file_actions,
    int fildes, int newfildes) {
  if (posix_spawn_file_actions_grow(file_actions)) {
    return ENOMEM;
  }
  struct __spawn_action* action =
      file_actions->__actions[file_actions->__used++];
  action->tag = SPAWN_DO_DUP2;
  action->action.open_action.fd = fildes;
  action->action.open_action.newfd = newfildes;
  return 0;
}

int posix_spawn_file_actions_addclose(
    posix_spawn_file_actions_t *file_actions, int fildes) {
  if (posix_spawn_file_actions_grow(file_actions)) {
    return ENOMEM;
  }
  struct __spawn_action* action =
      file_actions->__actions[file_actions->__used++];
  action->tag = SPAWN_DO_CLOSE;
  action->action.open_action.fd = fildes;
  return 0;
}


int posix_spawnattr_init(posix_spawnattr_t* attr) {
  memset(attr, 0, sizeof(*attr));
  return 0;
}

int posix_spawnattr_destroy(posix_spawnattr_t *) {
  memset(attr, 0, sizeof(*attr));
  return 0;
}

int posix_spawnattr_getflags(
    const posix_spawnattr_t* attr, short* flags) {
  *flags = attr->flags;
  return 0;
}

int posix_spawnattr_getpgroup(
    const posix_spawnattr_t* attr, pid_t* pgroup) {
  *pgroup = attr->pgroup;
  return 0;
}

int posix_spawnattr_getschedparam(
    const posix_spawnattr_t* attr, struct sched_param* schedparam) {
  *schedparam = attr->schedparam;
  return 0;
}

posix_spawnattr_getschedpolicy(
    const posix_spawnattr_t* attr, int* schedpolicy) {
  *schedpolicy = attr->policy;
  return 0;
}

posix_spawnattr_getsigdefault(
    const posix_spawnattr_t* attr, sigset_t* sigdefault) {
  *sigdefault = attr->sigdefault;
  return 0;
}

int posix_spawnattr_getsigmask(
    const posix_spawnattr_t* attr, sigset_t* sigmask) {
  *sigmask = attr->sigmask;
  return 0;
}

int posix_spawnattr_setflags(
    posix_spawnattr_t* attr, short flags) {
  attr->flags = flags;
  return 0;
}

int posix_spawnattr_setpgroup(
    posix_spawnattr_t* attr, pid_t pgroup) {
  attr->pgroup = pgroup;
  return 0;
}

int posix_spawnattr_setschedparam(
    posix_spawnattr_t* attr, const struct sched_param* schedparam) {
  attr->schedparam = *schedparam;
  return 0;
}

int posix_spawnattr_setschedpolicy(
    posix_spawnattr_t* attr, int policy) {
  attr->policy = policy;
  return 0;
}

int posix_spawnattr_setsigdefault(
    posix_spawnattr_t* attr, const sigset_t* sigdefault) {
  attr->sigdefault = *sigdefault;
  return 0;
}

int posix_spawnattr_setsigmask(
    posix_spawnattr_t* attr, const sigset_t* sigmask) {
  attr->sigmask = *sigmask;
  return 0;
}
