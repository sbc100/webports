/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef GLIBCEMU_SYS_TYPES_H
#define GLIBCEMU_SYS_TYPES_H 1

#if defined(__native_client__)
#include <stdint.h>
typedef int64_t _off_t;
typedef int64_t __dev_t;
typedef uint32_t __uid_t;
typedef uint32_t __gid_t;
typedef int32_t _ssize_t;
#endif

/*
 * TODO(sbc): remove once this is fixed:
 * https://code.google.com/p/nativeclient/issues/detail?id=3790
 */
#include <limits.h>
#define SSIZE_MAX ((ssize_t) (SIZE_MAX / 2))

#include_next <sys/types.h>

#endif  /* GLIBCEMU_SYS_TYPES_H */
