# Copyright 2011, The Native Client SDK Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can
# be found in the LICENSE file.

# Makefile for Stage 4 of the Life tutorial.

NACLPORTS_ROOT ?= ../../../..
INSTALL_ROOT ?= $$HOME/Sites/life-tutorial
INSTALL_DIR ?= $(INSTALL_ROOT)/life-stage-4

CCFILES = geturl_handler.cc jpeg_mem_src.cc life_module.cc life.cc
HFILES = life.h geturl_handler.h scoped_mutex_lock.h scoped_pixel_lock.h

CFLAGS = -Wall -Wno-long-long -pthread -Werror
INCLUDES = -I$(NACL_SDK_ROOT) -I$(NACLPORTS_ROOT)
LDFLAGS = -lppruntime \
          -lppapi_cpp \
          -lgoogle_nacl_platform \
          -lgio \
          -lpthread \
          -ljpeg \
          -lsrpc \
          $(ARCH_FLAGS)

RELEASE_MODULES = life_x86_32.nexe life_x86_64.nexe
DEBUG_MODULES = life_x86_32_dbg.nexe life_x86_64_dbg.nexe
ALL_MODULES = $(RELEASE_MODULES) $(DEBUG_MODULES)

APPLICATION_FILES = dragger.js \
                    life.html \
                    life.css \
                    life.js \
                    life.nmf \
                    spear.jpg \
                    $(RELEASE_MODULES)

# The check_variables target is in nacl_build.mk.
all: check_variables $(ALL_MODULES)

# nacl_build.mk has rules to build .o files from .cc files.
-include $(NACLPORTS_ROOT)/common_build_scripts/nacl_build.mk

LIB_JPEG_32 = $(NACL_SDK_ROOT)/$(NACL_TOOLCHAIN_DIR)/nacl/usr/lib/libjpeg.a
LIB_JPEG_64 = $(NACL_SDK_ROOT)/$(NACL_TOOLCHAIN_DIR)/nacl64/usr/lib/libjpeg.a
BOOST_SMART_PTR_32 = \
  $(NACL_SDK_ROOT)/$(NACL_TOOLCHAIN_DIR)/nacl/usr/include/boost/scoped_ptr.hpp
BOOST_SMART_PTR_64 = \
  $(NACL_SDK_ROOT)/$(NACL_TOOLCHAIN_DIR)/nacl64/usr/include/boost/scoped_ptr.hpp
PACKAGES = $(LIB_JPEG_32) \
           $(LIB_JPEG_64) \
           $(BOOST_SMART_PTR_32) \
           $(BOOST_SMART_PTR_64)

$(OBJECTS_X86_32) $(OBJECTS_X86_64) \
$(OBJECTS_X86_32_DBG) $(OBJECTS_X86_64_DBG):: $(HFILES) $(PACKAGES)

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

# Build the required packages.
$(LIB_JPEG_32):
	(cd $(NACLPORTS_ROOT)/packages/scripts/jpeg-6b; \
	export NACL_PACKAGES_BITSIZE=32; \
	./nacl-jpeg-6b.sh)

$(LIB_JPEG_64):
	(cd $(NACLPORTS_ROOT)/packages/scripts/jpeg-6b; \
	export NACL_PACKAGES_BITSIZE=64; \
	./nacl-jpeg-6b.sh)

$(BOOST_SMART_PTR_32):
	(cd $(NACLPORTS_ROOT)/packages/scripts/boost_1_43_0; \
	export NACL_PACKAGES_BITSIZE=32; \
	./nacl-boost_1_43_0.sh)

$(BOOST_SMART_PTR_64):
	(cd $(NACLPORTS_ROOT)/packages/scripts/boost_1_43_0; \
	export NACL_PACKAGES_BITSIZE=64; \
	./nacl-boost_1_43_0.sh)

clean:
	-$(RM) *.o *.obj *.nexe
