# Copyright 2010, The Native Client SDK Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can
# be found in the LICENSE file.

# Makefile for the Photo example.

.PHONY: all carpe clean

NACLPORTS_ROOT = ../../..
C_SALT_ROOT=../../../../../nacl-sdk-pepper2/src/c_salt

VPATH=$(C_SALT_ROOT) $(C_SALT_ROOT)/npapi

# $(OBJDIR) is an optional variable in nacl_build.mk, it is the directory
# that holds all the .o's.  Note that a rule to create this dir is built into
# common_build_scripts/nacl_build.mk
OBJDIR = obj

PHOTO_CCFILES = photo.cc

C_SALT_CCFILES = \
	  graphics_2d_context.cc \
          image.cc \
          image_manipulator.cc \
          jpeg_helper.cc \
          painter.cc \
          rect.cc \
          url_loader.cc \
          converting_visitor.cc \
          instance.cc \
          javascript_object_proxy.cc \
          notification_center.cc \
          module.cc \
          property.cc \
          scripting_bridge.cc \
          scriptable_native_object.cc \
          variant.cc

NPAPI_CCFILES = \
          browser_binding.cc \
          scoped_npid_to_string_converter.cc \
          variant_converter.cc \
          npn_bridge.cc \
          npp_gate.cc \

CCFILES = $(PHOTO_CCFILES) $(C_SALT_CCFILES) $(NPAPI_CCFILES)

CARPE_FILES = default.css slider.js

OBJECTS_X86_32 = $(patsubst %,${OBJDIR}/%,$(CFILES:%.c=%_x86_32.o))
OBJECTS_X86_32 += $(patsubst %,${OBJDIR}/%,$(CCFILES:%.cc=%_x86_32.o))
OBJECTS_X86_64 = $(patsubst %,${OBJDIR}/%,$(CFILES:%.c=%_x86_64.o))
OBJECTS_X86_64 += $(patsubst %,${OBJDIR}/%,$(CCFILES:%.cc=%_x86_64.o))

CFLAGS = -flax-vector-conversions -DXP_UNIX \
         -Wall -Wno-long-long -pthread -Werror
INCLUDES = -I$(NACL_SDK_ROOT) -I$(NACLPORTS_ROOT)

# This example uses linker aliasing to wrap the standard IO functions read(2),
# open(2), close(2) and lseek(2).  This aliasing causes the real functions to
# be aliased to __real_*, and calls to be turned into __wrap_*.  See
# nacl_file.c for implementation details.
LDFLAGS = $(ARCH_FLAGS) \
          -lgoogle_nacl_imc \
          -lgoogle_nacl_npruntime \
          -lpthread \
          -lgoogle_nacl_pgl \
          -lgoogle_nacl_gpu \
          -ljpeg \
          -lsrpc

OPT_FLAGS = -O3 \
            -mfpmath=sse \
            -msse3 \
            -fno-strict-aliasing \
            -funroll-loops \
            -fomit-frame-pointer

all: all_photo

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
           $(BOOST_SMART_PTR_64) \
           $(CARPE_FILES)

NACL_MODULES = photo_x86_32.nexe photo_x86_64.nexe

# The check_variables target is in nacl_build.mk.
all_photo: $(OBJDIR) check_variables $(PACKAGES) $(NACL_MODULES)

photo_x86_32.nexe: $(OBJECTS_X86_32)
	$(CPP) -m32 $^ $(LDFLAGS) -o $@

photo_x86_64.nexe: $(OBJECTS_X86_64)
	$(CPP) -m64 $^ $(LDFLAGS) -o $@

clean:
	-rm -rf $(OBJDIR) $(NACL_MODULES)

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

# Download and patch the Carpe sliders.
$(CARPE_FILES):
	/bin/bash photo_tool.sh
