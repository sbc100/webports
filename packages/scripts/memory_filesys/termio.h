/*
 * Copyright (c) 2010 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that be
 * found in the LICENSE file.
 */

#define TCGETA 1
#define TCSETAW 2
struct termio {
  int c_cflag;
  int c_iflag;
  int c_oflag;
  int c_lflag;
  int c_cc;
};
extern char PC;
extern char *UP;
extern char *BC;
extern short ospeed;
int tgetent(char *bp, const char *name);
int tgetflag(const char *id);
int tgetnum(const char *id);
char *tgetstr(const char *id, char **area);
char *tgoto(const char *cap, int col, int row);
void tputs(const char *str, int affcnt, int (*putc)(int));

