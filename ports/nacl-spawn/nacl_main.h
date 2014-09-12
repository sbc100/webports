/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifndef _NACL_SPAWN_NACL_MAIN_H_
#define _NACL_SPAWN_NACL_MAIN_H_

#include <spawn.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Entry point expected by libcli_main.a
 * Using C declaration so that variantions in arguments work.
 * Ensure default visibility in case a module is build with default hidden
 * visibility.
 */
extern __attribute__ (( visibility("default") )) int nacl_main();

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

#endif
