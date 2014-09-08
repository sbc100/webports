/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef _GLIBCEMU_SYS_DIRENT_H
#define _GLIBCEMU_SYS_DIRENT_H

#include <sys/cdefs.h>
#include_next <sys/dirent.h>

__BEGIN_DECLS

int readdir_r(DIR *dirp, struct dirent *entry, struct dirent **result);

__END_DECLS

#endif
