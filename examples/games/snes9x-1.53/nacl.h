/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <stdint.h>
#include "event_queue.h"

extern void S9xNaclInit(uint32_t *data, uint32_t pitch);
extern void S9xNaclMapInput();
extern void S9xNaclDraw(int width, int height);
extern void S9xResizeWindow(int mode);

extern EventQueue event_queue;
