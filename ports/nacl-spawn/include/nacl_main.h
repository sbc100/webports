/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifndef NACL_SPAWN_NACL_MAIN_H_
#define NACL_SPAWN_NACL_MAIN_H_

#include <spawn.h>

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

#ifdef __cplusplus
}
#endif

#endif /* NACL_SPAWN_NACL_MAIN_H_ */
