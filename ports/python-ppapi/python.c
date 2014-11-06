/* Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

#include <Python.h>

#include "nacl_main.h"

extern int nacl_startup_untar(
    const char* argv0, const char* tarfile, const char* root);

#ifdef __arm__
#define DATA_FILE "_platform_specific/arm/pydata_arm.tar"
#elif defined __i386__
#define DATA_FILE "_platform_specific/x86_32/pydata_x86_32.tar"
#elif defined __x86_64__
#define DATA_FILE "_platform_specific/x86_64/pydata_x86_64.tar"
#elif defined __pnacl__
#define DATA_FILE "pydata_pnacl.tar"
#else
#error "Unknown arch"
#endif

int nacl_main(int argc, char **argv) {
  if (nacl_startup_untar(argv[0], DATA_FILE, "/"))
    return -1;

  return Py_Main(argc, argv);
}
