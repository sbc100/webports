# Copyright 2010, The Native Client SDK Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can
# be found in the LICENSE file.

# Makefile for the Matrix example.

.PHONY:  all clean

NACLPORTS_ROOT = ../../..

CCFILES = perf_test.cc

#OBJECTS_X86_32 = $(CCFILES:%.cc=%_x86_32.o)
#OBJECTS_X86_64 = $(CCFILES:%.cc=%_x86_64.o)


CFLAGS = -Wall -Wno-long-long -pthread -DXP_UNIX -Werror
INCLUDES = -I$(NACL_SDK_ROOT) -I$(NACLPORTS_ROOT)

LDFLAGS = -lppruntime \
          -lppapi_cpp \
          -lgoogle_nacl_platform \
          -lgio \
          -lpthread \
          -lsrpc \
          $(ARCH_FLAGS)


OPT_FLAGS = -O2

all: all_perf_test

# common.mk has rules to build .o files from .cc files.
-include $(NACLPORTS_ROOT)/common_build_scripts/nacl_build.mk

all_perf_test: check_variables perf_test_x86_32.nexe perf_test_x86_64.nexe

perf_test_x86_32.nexe: $(OBJECTS_X86_32)
	$(CPP) $^ $(LDFLAGS) -m32 -o $@

perf_test_x86_64.nexe: $(OBJECTS_X86_64)
	$(CPP) $^ $(LDFLAGS) -m64 -o $@

clean:
	-$(RM) $(OBJECTS_X86_32) $(OBJECTS_X86_64) *.nexe
