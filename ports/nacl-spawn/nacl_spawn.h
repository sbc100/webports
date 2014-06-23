/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifndef _NACL_SPAWN_H_
#define _NACL_SPAWN_H_

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
 *   argv: The startup arguments for the child.
 * Returns:
 *   Process id of the child or -1 for error.
 */
extern int nacl_spawn_simple(const char** argv);

/*
 * Wait for a process to complete.
 * Args:
 *   pid: Process id to wait on, or -1 for all children.
 *   status: Address to store exit code to or NULL.
 *   options: 0 or WNOHANG (to poll).
 * Returns:
 *   Process id of completed child, 0 for none, or -1 for error.
 */
extern int nacl_waitpid(int pid, int* status, int options);

#ifdef __cplusplus
}
#endif

#endif /* _NACL_SPAWN_CLI_MAIN_H_ */
