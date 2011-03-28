# Copyright 2011, The Native Client SDK Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can
# be found in the LICENSE file.

# Makefile for the Hello World example.

.PHONY: all clean

CCFILES = chess_engine.cc

#NACL_SDK_ROOT = ../..

NACL_SDK_ROOT = /Users/mmortensen/nacl_sdk_705/native_client_sdk_0_1_721_0
NACLPORTS_ROOT = ../../..

INCLUDES = -I$(NACL_SDK_ROOT)

LDFLAGS = -lppruntime \
          -lppapi_cpp \
          -lgoogle_nacl_platform \
          -lgio \
          -lpthread \
          -lsrpc \
          $(ARCH_FLAGS)

all: all_chess

-include $(NACLPORTS_ROOT)/src/common_build_scripts/nacl_build.mk

all_chess: check_variables chess_engine_x86_32.nexe chess_engine_x86_64.nexe

# common.mk has rules to build .o files from .cc files.

chess_engine_x86_32.nexe: $(OBJECTS_X86_32)
	$(CPP) $^ $(LDFLAGS) -m32 -o $@
	$(NACL_STRIP) $@ -o $@

chess_engine_x86_64.nexe: $(OBJECTS_X86_64)
	$(CPP) $^ $(LDFLAGS) -m64 -o $@
	$(NACL_STRIP) $@ -o $@

chess_engine_x86_32_dbg.nexe: $(OBJECTS_X86_32_DBG)
	$(CPP) $^ $(LDFLAGS) -m32 -o $@

chess_engine_x86_64_dbg.nexe: $(OBJECTS_X86_64_DBG)
	$(CPP) $^ $(LDFLAGS) -m64 -o $@

clean:
	-$(RM) *.o *.nexe *.obj

# This target is used by the SDK build system to produce a pre-built version
# of the .nexe.  You do not need to call this target.
install_prebuilt: hello_world.nmf
	-$(RM) $(OBJECTS_X86_32) $(OBJECTS_X86_64)
