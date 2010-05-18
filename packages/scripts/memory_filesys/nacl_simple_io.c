/*
 * Copyright (c) 2010 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that be
 * found in the LICENSE file.
 */

#include <assert.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <unistd.h>
#include "nacl_escape.h"
#ifdef __native_client__
#  include <nacl/nacl_srpc.h>
#endif

/* Monitor over the works. */
static pthread_mutex_t console_master_lock;
/* in-out from the point of view of the nacl module */
static char *input_buffer = 0;
static int input_buffer_length = 0;
static int input_buffer_capacity = 0;
static pthread_cond_t input_ready;
static char *output_buffer = 0;
static int output_buffer_length = 0;
static int output_buffer_capacity = 0;

static pthread_once_t console_has_started = PTHREAD_ONCE_INIT;

static void console_init_once(void) {
  /* Setup file system master lock. */
  if (pthread_mutex_init(&console_master_lock, NULL)) assert(0);
  /* Setup input ready condition. */
  if (pthread_cond_init(&input_ready, NULL)) assert(0);
}

static void console_lock(void) {
  if (pthread_once(&console_has_started, console_init_once)) assert(0);
  if (pthread_mutex_lock(&console_master_lock)) assert(0);
}

static void console_unlock(void) {
  if (pthread_mutex_unlock(&console_master_lock)) assert(0);
}

void console_put(const char *str, int str_len) {
  console_lock();

  /* Fill output buffer. */
  if (output_buffer_capacity < str_len + output_buffer_length) {
    output_buffer_capacity = (str_len + output_buffer_length) * 2;
    output_buffer = (char*)realloc(output_buffer, output_buffer_capacity);
    assert(output_buffer);
  }
  memcpy(output_buffer + output_buffer_length, str, str_len);
  output_buffer_length += str_len;

  console_unlock();
}

int console_get(void) {
  int ret;

  console_lock();

  /* Wait until there's input. */
  while (input_buffer_length < 1) {
    pthread_cond_wait(&input_ready, &console_master_lock);
  }

  /* Pull out one character. */
  ret = *(unsigned char*)input_buffer;
  memmove(input_buffer, input_buffer + 1, input_buffer_length - 1);
  --input_buffer_length;

  console_unlock();

  return ret;
}

int __wrap___srget_r(struct _reent *ptr, register FILE *fp) {
  if (fp == stdin) {
    return console_get();
  } else {
    return __real___srget_r(ptr, fp);
  }
}

int __wrap_getchar(void) {
  return console_get();
}

int __wrap_tgetch(void) {
  return console_get();
}

int console_get_nonblock(void) {
  int ret;

  console_lock();

  if (input_buffer_length < 1) {
    ret = -1;
  } else {
    /* Pull out one character. */
    ret = *(unsigned char*)input_buffer;
    memmove(input_buffer, input_buffer + 1, input_buffer_length - 1);
    --input_buffer_length;
  }

  console_unlock();

  return ret;
}

int puts(const char *s) {
  console_put(s, strlen(s));
  console_put("\n", 1);
  return 0;
}

/* exports for termcap */
char PC = 0;
char *UP = "";
char *BC = "";
short ospeed = 0;  /* short is used to match termcap definition, ignore lint */

int tgetent(char *bp, const char *name) {
  /* Always succeed. */
  return 1;
}

int tgetflag(const char *id) {
  /* backspace can be used to move left */
  if (strcmp(id, "bs") == 0) return 1;
  /* character in the last column wraps to the next line */
  if (strcmp(id, "am") == 0) return 1;
  /* wrapping happens in strange ways */
  if (strcmp(id, "xn") == 0) return 1;
  /* backspace at col 0 goes up a line */
  if (strcmp(id, "bw") == 0) return 1;  // diff from xterm-color
  /* safe to move in standout mode */
  if (strcmp(id, "ms") == 0) return 1;
  return 0;
}

int tgetnum(const char *id) {
  /* columns */
  if (strcmp(id, "co") == 0) return 80;
  /* rows */
  if (strcmp(id, "li") == 0) return 25;
  return -1;
}

char *tgetstr(const char *id, char **area) {
  /* how to move to specific location */
  if (strcmp(id, "cm") == 0) return strdup("\x1b[%i%d;%dH");
  /* how to move to upper left */
  if (strcmp(id, "ho") == 0) return strdup("\x1b[H");

  /* how to move right one character */
  if (strcmp(id, "nd") == 0) return strdup("\x1b" "[C");
  /* how to move up one character */
  if (strcmp(id, "up") == 0) return strdup("\x1b" "[A");
  /* how to clear the screen */
  if (strcmp(id, "do") == 0) return strdup("\x1b" "[B");

  /* how to clear the rest of the line */
  if (strcmp(id, "ce") == 0) return strdup("\x1b" "[K");
  /* how to clear the rest of the screen */
  if (strcmp(id, "cd") == 0) return strdup("\x1b" "[J");
  /* how to clear the screen */
  if (strcmp(id, "cl") == 0) return strdup("\x1b" "[H" "\x1b" "[J");

  /* how to jump to the front of this line (cr) */
  if (strcmp(id, "cr") == 0) return strdup("\r");
  /* move down a line (lf) */
  if (strcmp(id, "nl") == 0) return strdup("\n");
  /* move to start of next line */
  if (strcmp(id, "nw") == 0) return strdup("\n\r");
  /* how to move left one character */
  if (strcmp(id, "le") == 0) return strdup("\x08");

  /* standout on */
  if (strcmp(id, "so") == 0) return strdup("\x1b" "[7m");
  /* double-bright on */
  if (strcmp(id, "md") == 0) return strdup("\x1b" "[1m");
  /* half-bright on */
  if (strcmp(id, "mh") == 0) return strdup("\x1b" "[2m");
  /* reverse on */
  if (strcmp(id, "mr") == 0) return strdup("\x1b" "[7m");
  /* underline on */
  if (strcmp(id, "us") == 0) return strdup("\x1b" "[4m");
  /* various modes off */
  if (strcmp(id, "ue") == 0) return strdup("\x1b" "[m");
  if (strcmp(id, "se") == 0) return strdup("\x1b" "[m");
  if (strcmp(id, "me") == 0) return strdup("\x1b" "[m");

  return 0;
}

char *tgoto(const char *cap, int col, int row) {
  #define FORMAT_STRING_LIMIT 1000
  static char dst_str[FORMAT_STRING_LIMIT];
  char *dst = dst_str;
  char ch;
  int values[2];
  int position;
  int tmp;

  /* NOT THREAD SAFE!!! */
  values[0] = row;
  values[1] = col;
  position = 0;
  while (*cap) {
    ch = *cap;
    cap++;
    if (ch == '%') {
      ch = *cap;
      cap++;
      if (ch == '%') {
        *dst = '%';
        dst++;
      } else if (ch == 'd') {
        snprintf(dst, FORMAT_STRING_LIMIT, "%d", values[position]);
        dst += strlen(dst);
        position++;
      } else if (ch == '2') {
        snprintf(dst, FORMAT_STRING_LIMIT, "%02d", values[position]);
        dst += strlen(dst);
        position++;
      } else if (ch == '3') {
        snprintf(dst, FORMAT_STRING_LIMIT, "%03d", values[position]);
        dst += strlen(dst);
        position++;
      } else if (ch == '.') {
        snprintf(dst, FORMAT_STRING_LIMIT, "%c", values[position]);
        dst += strlen(dst);
        position++;
      } else if (ch == 'r') {
        tmp = values[0];
        values[0] = values[1];
        values[1] = tmp;
      } else if (ch == 'i') {
        values[0]++;
        values[1]++;
      }
    } else {
      *dst = ch;
      dst++;
    }
  }
  *dst = 0;
  return dst_str;
}

int tputs(const char *str, int affcnt, int (*putc_)(int)) {
  while (*str) {
    putc_(*str);
    str++;
  }
  return 0;
}

int has_colors(void) {
  return 1;
}

#ifdef __native_client__

NaClSrpcError NaClConsole(NaClSrpcChannel *channel,
                          NaClSrpcArg **in_args,
                          NaClSrpcArg **out_args) {
  char *tmp;
  int tmp_len;

  unescape_string(in_args[0]->u.sval, &tmp, &tmp_len);

  console_lock();

  /* Fill input buffer. */
  if (input_buffer_capacity < tmp_len + input_buffer_length) {
    input_buffer_capacity = (tmp_len + input_buffer_length) * 2;
    input_buffer = (char*)realloc(input_buffer, input_buffer_capacity);
    assert(input_buffer);
  }
  memcpy(input_buffer + input_buffer_length, tmp, tmp_len);
  input_buffer_length += tmp_len;

  /* Signal ready on input. */
  if (input_buffer_length > 0) {
    pthread_cond_broadcast(&input_ready);
  }

  /* Drain output buffer. */
  out_args[0]->u.sval = escape_string(output_buffer,
                                      output_buffer_length);
  free(output_buffer);
  output_buffer = 0;
  output_buffer_capacity = 0;
  output_buffer_length = 0;

  console_unlock();

  free(tmp);
  return NACL_SRPC_RESULT_OK;
}
NACL_SRPC_METHOD("console:s:s", NaClConsole);

#endif
