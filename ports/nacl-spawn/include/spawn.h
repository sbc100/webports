/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <sys/types.h>
#include <sys/wait.h>

#ifdef __BIONIC__
// TODO(sbc): remove this once bionic toolchain gets a copy of
// spawn.h.
#include <bsd_spawn.h>
#else
#include_next <spawn.h>
#endif

/*
 * Include guards are here so that this header can forward to the next one in
 * presence of an already installed copy of nacl-spawn.
 */
#ifndef NACL_SPAWN_SPAWN_H_
#define NACL_SPAWN_SPAWN_H_

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

/*
 * Synchronously eval JavaScript.
 *
 * Args:
 *   cmd: Null terminated string containing code to eval.
 *   data: Pointer to a char* to receive eval string result.
 *   len: Pointer to a size_t to receive the length of the result.
 */
extern void jseval(const char* cmd, char** data, size_t* len);

#ifdef __cplusplus
}
#endif

#endif /* NACL_SPAWN_SPAWN_H_ */
