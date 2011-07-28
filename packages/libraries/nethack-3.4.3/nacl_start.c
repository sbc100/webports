/*
 * Copyright (c) 2010 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that be
 * found in the LICENSE file.
 */

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

extern int NaClFileSrpc(void);

static void *handle_srpc(void *args) {
  NaClFileSrpc();
}

int nacl_startup() {
  pthread_t thread;

  /* Fork a new thread to handle srpc. */
  pthread_create(&thread, NULL, handle_srpc, 0);
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
