# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Build rotating earth demo with Pepper in C, Pepper in C++, and NaCl-SDL

NACLPORTS_ROOT ?= ../../..
NACL_TOOLCHAIN_ROOT=$(NACL_SDK_ROOT)/toolchain/mac_x86_newlib
NACL_CC	= $(NACL_TOOLCHAIN_ROOT)/bin/nacl-gcc
NACL_CXX = $(NACL_TOOLCHAIN_ROOT)/bin/nacl-g++
NACL_LD = $(NACL_TOOLCHAIN_ROOT)/bin/nacl-g++
CCFLAGS	+= -O3 -msse2 -mfpmath=sse -fomit-frame-pointer
CCFLAGS += -std=gnu++98 -Wno-long-long -Wall -pedantic -Werror
LIBS	 += -lpthread -lm -lppruntime -lppapi_cpp -lplatform -lgio -lsrpc





# SDL_CCFLAGS is from `$(NACL_TOOLCHAIN_ROOT)/nacl/usr/bin/sdl-config --cflags`
SDL_CCFLAGS = -I$(NACL_TOOLCHAIN_ROOT)/nacl/usr/include/SDL \
             -D_GNU_SOURCE=1 -D_REENTRANT $(CCFLAGS)
# SDL_LIBS is from `$(NACL_TOOLCHAIN_ROOT)/nacl/usr/bin/sdl-config --libs`
SDL_LIBS = -L$(NACL_TOOLCHAIN_ROOT)/nacl/usr/lib -lSDL -lpthread -lm $(LIBS)
SDL_LIBS64 = -L$(NACL_TOOLCHAIN_ROOT)/nacl64/usr/lib -lSDL -lpthread -lm $(LIBS)
LIBSDL=$(NACL_TOOLCHAIN_ROOT)/nacl/usr/lib/libSDL.a
LIBSDL64=$(NACL_TOOLCHAIN_ROOT)/nacl64/usr/lib/libSDL.a

# The check_variables target is in nacl_build.mk
# Build SDL targets last in case naclports SDL has not been built
all: check_variables \
    earth_c_x86_32.nexe earth_cc_x86_32.nexe \
    earth_c_x86_64.nexe earth_cc_x86_64.nexe \
    earth_sdl_x86_32.nexe earth_sdl_x86_64.nexe

# nacl_build.mk has rules to build .o files from .cc files.
-include $(NACLPORTS_ROOT)/common_build_scripts/nacl_build.mk

earth_sdl_x86_32.nexe: sdl.c earth.cc pepper_plugin.cc $(LIBSDL)
	 $(NACL_CXX) -o $@ $^ $(SDL_CCFLAGS) $(SDL_LIBS)

earth_c_x86_32.nexe: earth.cc pepper_cc.cc
	 $(NACL_CXX) -o $@ $^ $(CCFLAGS) $(LIBS)

earth_cc_x86_32.nexe: earth.cc pepper_c.c
	 $(NACL_CXX) -o $@ $^ $(CCFLAGS) $(LIBS)

earth_sdl_x86_64.nexe: sdl.c earth.cc pepper_plugin.cc $(LIBSDL64)
	 $(NACL_CXX) -o $@ $^ -m64 $(SDL_CCFLAGS) $(SDL_LIBS)

earth_c_x86_64.nexe: earth.cc pepper_cc.cc
	 $(NACL_CXX) -o $@ $^ -m64 $(CCFLAGS) $(LIBS)

earth_cc_x86_64.nexe: earth.cc pepper_c.c
	 $(NACL_CXX) -o $@ $^ -m64 $(CCFLAGS) $(LIBS)

clean:
	rm -f *.o *.nexe
