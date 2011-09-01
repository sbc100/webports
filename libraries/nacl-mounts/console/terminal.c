/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <assert.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <unistd.h>


#ifndef __GLIBC__
int __wrap___srget_r(struct _reent *ptr, register FILE *fp) {
  if (fp == stdin) {
    return __wrap_getchar();
  } else {
    return __real___srget_r(ptr, fp);
  }
}
#endif

int __wrap_getchar(void) {
  char ch;
  int ret;

  ret = __wrap_read(0, &ch, 1);
  if (ret == 1) return ch;
  return -1;
}

int __wrap_tgetch(void) {
  return __wrap_getchar();
}

int puts(const char *s) {
  write(1, s, strlen(s));
  write(1, "\n", 1);
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
