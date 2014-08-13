/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifndef _NACL_SPAWN_SPAWN_H_
#define _NACL_SPAWN_SPAWN_H_

#include <sys/types.h>
#include <sys/wait.h>

#include_next <spawn.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Spawn a child using the given args.
 *
 * Args:
 *   mode: Execute mode, one of the defines below.
 *   path: The program to run.
 *   argv: The startup arguments for the child.
 * Returns:
 *   Process id of the child or -1 for error.
 */
extern int spawnv(int mode, const char* path, char *const argv[]);

/*
 * Spawn a child using the current environment and given args.
 *
 * Args:
 *   mode: Execute mode, one of the defines below.
 *   path: The program to run.
 *   argv: The startup arguments for the child.
 *   envp: The environment to run the child in.
 * Returns:
 *   Process id of the child or -1 for error.
 */
extern int spawnve(int mode, const char* path,
                   char *const argv[], char *const envp[]);
#define P_WAIT 0
#define P_NOWAIT 1
#define P_NOWAITO 1
#define P_OVERLAY 2

#ifdef __cplusplus
}
#endif

#endif
