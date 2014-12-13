# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

CFLAGS += -Wno-implicit-function-declaration
CPPFLAGS := -Werror -Wno-unused-value
CPPFLAGS += -pthread -Iinclude -Isrc -D_LIBC
CPPFLAGS += -DNACL_SDK_VERSION=$(NACL_SDK_VERSION)
CPPFLAGS += -I$(NACL_SDK_ROOT)/include
OUT := out
SOURCES := \
  src/getprotobyname_r.c \
  src/getservbyname_r.c \
  src/herrno.c \
  src/herror.c \
  src/in6_addr.c \
  src/inet_addr.c \
  src/inet_pton.c \
  src/mktemp.c \
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
  src/res_send.c

OBJS := $(patsubst src/%.c,$(OUT)/%.o,$(SOURCES))

ifeq ($(V),1)
CXX_PREFIX =
CC_PREFIX =
AR_PREFIX =
else
CXX_PREFIX = @echo " CXX $@";
CC_PREFIX =  @echo " CC  $@";
AR_PREFIX =  @echo " AR  $@";
endif

$(OUT)/%.o : src/%.c
	@mkdir -p $(OUT)
	$(CC_PREFIX)$(CC) -o $@ -c $< $(CFLAGS) $(CPPFLAGS)

all: $(OUT)/libglibc-compat.a $(OUT)/glibc_compat_test

$(OUT)/libglibc-compat.a: $(OBJS)
	$(AR_PREFIX)$(AR) rcs $@ $^

LIBS=-lglibc-compat -lgtest -lpthread

$(OUT)/glibc_compat_test: src/test.cc $(OUT)/libglibc-compat.a
	$(CXX_PREFIX)$(CXX) -o $@ $< -L$(OUT) $(LDFLAGS) $(CXXFLAGS) \
		$(CPPFLAGS) $(LIBS)

test: $(OUT)/glibc_compat_test

clean:
	rm -rf $(OUT)

.PHONY: test clean all
