# Copyright 2011, The Native Client SDK Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can
# be found in the LICENSE file.

# Makefile for Stage 2 of the Life tutorial.

NACLPORTS_ROOT ?= ../../../..
INSTALL_ROOT ?= $$HOME/Sites/life-tutorial
INSTALL_DIR ?= $(INSTALL_ROOT)/life-stage-2

CCFILES = life_module.cc life.cc
HFILES = life.h scoped_mutex_lock.h scoped_pixel_lock.h

CFLAGS = -Wall -Wno-long-long -pthread -Werror
INCLUDES = -I$(NACL_SDK_ROOT) -I$(NACLPORTS_ROOT)
LDFLAGS = -lppruntime \
          -lppapi_cpp \
          -lplatform \
          -lgio \
          -lpthread \
          -lsrpc \
          $(ARCH_FLAGS)

RELEASE_MODULES = life_x86_32.nexe life_x86_64.nexe
DEBUG_MODULES = life_x86_32_dbg.nexe life_x86_64_dbg.nexe
ALL_MODULES = $(RELEASE_MODULES) $(DEBUG_MODULES)

APPLICATION_FILES = life.html \
                    life.css \
                    life.nmf \
                    $(RELEASE_MODULES)

# The check_variables target is in nacl_build.mk.
all: check_variables $(ALL_MODULES)

# nacl_build.mk has rules to build .o files from .cc files.
-include $(NACLPORTS_ROOT)/common_build_scripts/nacl_build.mk

$(OBJECTS_X86_32) $(OBJECTS_X86_64) \
$(OBJECTS_X86_32_DBG) $(OBJECTS_X86_64_DBG):: $(HFILES)

life_x86_32.nexe: $(OBJECTS_X86_32)
	$(CPP) $^ $(LDFLAGS) -m32 -o $@
	$(NACL_STRIP) $@ -o $@

life_x86_64.nexe: $(OBJECTS_X86_64)
	$(CPP) $^ $(LDFLAGS) -m64 -o $@
	$(NACL_STRIP) $@ -o $@

life_x86_32_dbg.nexe: $(OBJECTS_X86_32_DBG)
	$(CPP) $^ $(LDFLAGS) -m32 -o $@

life_x86_64_dbg.nexe: $(OBJECTS_X86_64_DBG)
	$(CPP) $^ $(LDFLAGS) -m64 -o $@

install: $(APPLICATION_FILES) $(INSTALL_DIR)
	install $(APPLICATION_FILES) $(INSTALL_DIR)

$(INSTALL_DIR):
	mkdir -p $@

clean:
	-$(RM) *.o *.obj *.nexe
