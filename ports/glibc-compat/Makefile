# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

CFLAGS := -Wno-error -pthread -Iinclude -Isrc -D_LIBC -DNACL_SDK_VERSION=$(NACL_SDK_VERSION)
OUT := out
SOURCES := \
  src/getprotobyname_r.c \
  src/getservbyname_r.c \
  src/herrno.c \
  src/in6_addr.c \
  src/inet_addr.c \
  src/inet_pton.c \
  src/ns_name.c \
  src/ns_netint.c \
  src/ns_samedomain.c \
  src/qsort_r.c \
  src/res_comp.c \
  src/res_data.c \
  src/res_debug.c \
  src/res_init.c \
  src/res_libc.c \
  src/res_mkquery.c \
  src/res_query.c \
  src/res_send.c \
  src/stubs.c

OBJS := $(patsubst src/%.c,$(OUT)/%.o,$(SOURCES))

$(OUT)/%.o : src/%.c
	$(CC) -o $@ -c $< $(CFLAGS)

all: .dirs $(OUT)/libglibc-compat.a

$(OUT)/libglibc-compat.a: $(OBJS)
	$(AR) rcs $@ $^

.PHONY: .dirs clean all

clean:
	rm -rf $(OUT)

.dirs:
	mkdir -p $(OUT)
