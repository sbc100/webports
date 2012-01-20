/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_UTIL_PPAPI_VERSION_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_UTIL_PPAPI_VERSION_H_

// Horrible hack to determine ppapi version
// TODO: figure something out for 17
#include <ppapi/c/ppb_var.h>

#ifdef PPB_VAR_INTERFACE_1_1
#define ADHOC_PPAPI_VERSION 18
#else
#define ADHOC_PPAPI_VERSION 16
#endif

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_UTIL_VERSION_H_
