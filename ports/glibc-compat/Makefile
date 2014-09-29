# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

CFLAGS := -Werror -Wno-implicit-function-declaration -Wno-unused-value
CFLAGS += -pthread -Iinclude -Isrc -D_LIBC
CFLAGS += -DNACL_SDK_VERSION=$(NACL_SDK_VERSION)
CFLAGS += -I$(NACL_SDK_ROOT)/include
OUT := out
SOURCES := \
  src/getprotobyname_r.c \
  src/getservbyname_r.c \
  src/herrno.c \
  src/herror.c \
  src/in6_addr.c \
  src/inet_addr.c \
  src/inet_pton.c \
  src/ns_name.c \
  src/ns_netint.c \
  src/ns_samedomain.c \
  src/qsort_r.c \
  src/random.c \
  src/realpath.c \
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

ifeq ($(V),1)
CC_PREFIX=
AR_PREFIX=
else
CC_PREFIX=@echo " CC $@";
AR_PREFIX=@echo " AR $@";
endif

$(OUT)/%.o : src/%.c
	@mkdir -p $(OUT)
	$(CC_PREFIX) $(CC) -o $@ -c $< $(CFLAGS)

all: $(OUT)/libglibc-compat.a

$(OUT)/libglibc-compat.a: $(OBJS)
	@echo " AR $@"; $(AR) rcs $@ $^

.PHONY: clean all

clean:
	rm -rf $(OUT)
