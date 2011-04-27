# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Makefile for the Matrix example.

.PHONY:  all clean

#NACLPORTS_ROOT = ../../..
NACLPORTS_ROOT = ../..

CCFILES = hex.cc

#OBJECTS_X86_32 = $(CCFILES:%.cc=%_x86_32.o)
#OBJECTS_X86_64 = $(CCFILES:%.cc=%_x86_64.o)

#NACL_SDK_ROOT = /Users/mmortensen/nacl_sdk_705/native_client_sdk_0_1_721_0
CFLAGS = -Wall -Wno-long-long -pthread -DXP_UNIX -Werror
INCLUDES = -I$(NACLPORTS_ROOT)

# PLEASE NOTE: If you are using a NaCl SDK version 0.1 you must use
# -lgoogle_nacl_platform instead of -lplatform
LDFLAGS = -lppruntime \
          -lppapi_cpp \
          -lplatform \
          -lgio \
          -lpthread \
          -lsrpc \
          $(ARCH_FLAGS)


OPT_FLAGS = -O2

all: all_hex

# common.mk has rules to build .o files from .cc files.
-include $(NACLPORTS_ROOT)/common_build_scripts/nacl_build.mk

all_hex: check_variables hex_x86_32.nexe hex_x86_64.nexe

hex_x86_32.nexe: $(OBJECTS_X86_32)
	$(CPP) $^ $(LDFLAGS) -m32 -o $@

hex_x86_64.nexe: $(OBJECTS_X86_64)
	$(CPP) $^ $(LDFLAGS) -m64 -o $@

clean:
	-$(RM) $(OBJECTS_X86_32) $(OBJECTS_X86_64) *.nexe

