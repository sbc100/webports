# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Build rotating earth demo with Pepper in C, Pepper in C++, and NaCl-SDL

NACLPORTS_ROOT ?= ../../..
CCFLAGS	+= -O3 -msse2 -mfpmath=sse -fomit-frame-pointer
CCFLAGS += -std=gnu++98 -Wno-long-long -Wall -pedantic -Werror
LIBS	 += -lpthread -lm -lppruntime -lppapi_cpp -lplatform -lgio -lsrpc

# The check_variables target is in nacl_build.mk
# Build SDL targets last in case naclports SDL has not been built
all: check_variables \
    earth_c_x86_32.nexe earth_cc_x86_32.nexe \
    earth_c_x86_64.nexe earth_cc_x86_64.nexe \
    earth_sdl_x86_32.nexe earth_sdl_x86_64.nexe

# nacl_build.mk has rules to build .o files from .cc files.
-include $(NACLPORTS_ROOT)/common_build_scripts/nacl_build.mk

NACL_TOOLCHAIN_ROOT=$(NACL_SDK_ROOT)/$(NACL_TOOLCHAIN_DIR)
# SDL_CCFLAGS is from `$(NACL_TOOLCHAIN_ROOT)/nacl/usr/bin/sdl-config --cflags`
SDL_CCFLAGS = -I$(NACL_TOOLCHAIN_ROOT)/nacl/usr/include/SDL \
             -D_GNU_SOURCE=1 -D_REENTRANT $(CCFLAGS)
# SDL_LIBS is from `$(NACL_TOOLCHAIN_ROOT)/nacl/usr/bin/sdl-config --libs`
SDL_LIBS = -L$(NACL_TOOLCHAIN_ROOT)/nacl/usr/lib -lSDL -lpthread -lm $(LIBS)
SDL_LIBS64 = -L$(NACL_TOOLCHAIN_ROOT)/nacl64/usr/lib -lSDL -lpthread -lm $(LIBS)
LIBSDL=$(NACL_TOOLCHAIN_ROOT)/nacl/usr/lib/libSDL.a
LIBSDL64=$(NACL_TOOLCHAIN_ROOT)/nacl64/usr/lib/libSDL.a

earth_sdl_x86_32.nexe: sdl.c earth.cc pepper_plugin.cc $(LIBSDL)
	 $(CPP) -o $@ $^ $(SDL_CCFLAGS) $(SDL_LIBS)

earth_c_x86_32.nexe: earth.cc pepper_c.c
	 $(CPP) -o $@ $^ $(CCFLAGS) $(LIBS)

earth_cc_x86_32.nexe: earth.cc pepper_cc.cc
	 $(CPP) -o $@ $^ $(CCFLAGS) $(LIBS)

earth_sdl_x86_64.nexe: sdl.c earth.cc pepper_plugin.cc $(LIBSDL64)
	 $(CPP) -o $@ $^ -m64 $(SDL_CCFLAGS) $(SDL_LIBS)

earth_c_x86_64.nexe: earth.cc pepper_c.c
	 $(CPP) -o $@ $^ -m64 $(CCFLAGS) $(LIBS)

earth_cc_x86_64.nexe: earth.cc pepper_cc.cc
	 $(CPP) -o $@ $^ -m64 $(CCFLAGS) $(LIBS)

$(LIBSDL):
	@echo Could not find $@
	@echo Please run nacl-install-all.sh in ../../packages first
	@exit -1

$(LIBSDL64):
	@echo Could not find $@
	@echo Please run nacl-install-all.sh in ../../packages first
	@exit -1

clean:
	rm -f *.o *.nexe
