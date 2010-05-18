/*
 * Copyright (c) 2010 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that be
 * found in the LICENSE file.
 */

#include <stdio.h>
#include <stdlib.h>

int nacl_startup() {
  /* Setup home directory to a known location. */
  setenv("HOME", "/myhome", 1); 
  /* Setup terminal type. */
  setenv("TERM", "xterm-color", 1);
  /* Blank out USER and LOGNAME. */
  setenv("USER", "", 1);
  setenv("LOGNAME", "", 1);

  /* Wait for a character, to get in sync. */
  getchar();

  return 1;
}
