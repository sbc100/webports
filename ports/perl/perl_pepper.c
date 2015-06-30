/*
 * Copyright (c) 2015 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "nacl_main.h"

extern int nacl_perl_main(int argc, char* argv[]);

int nacl_main(int argc, char* argv[]) {
  if (nacl_startup_untar(argv[0], "perl.tar", "/"))
    return 1;
  return nacl_perl_main(argc, argv);
}
