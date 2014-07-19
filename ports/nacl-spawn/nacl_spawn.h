/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifndef _NACL_SPAWN_H_
#define _NACL_SPAWN_H_

#include <sys/types.h>
#include <sys/wait.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Entry point expected by libcli_main.a
 */
extern int nacl_main(int argc, char* argv[]);

/*
 * Untar a startup bundle to a particular root.
 *
 * NOTE: This lives in libcli_main.a
 * Args:
 *   arg0: The contents of argv[0], used to determine relative tar location.
 *   tarfile: The name of a tarfile to extract.
 *   root: The absolute path to extract the startup tar file to.
 */
extern int nacl_startup_untar(
    const char* argv0, const char* tarfile, const char* root);

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
#define P_WAIT 1
#define P_NOWAIT 2
#define P_NOWAITO 3
#define O_OVERLAY 4

#ifdef __cplusplus
}
#endif

#endif /* _NACL_SPAWN_CLI_MAIN_H_ */
