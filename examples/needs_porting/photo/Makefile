# Copyright 2010, The Native Client SDK Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can
# be found in the LICENSE file.

# Makefile for the Photo example.

.PHONY: packages clean carpe

CCFILES = loader.cc \
          npn_bridge.cc \
          npp_gate.cc \
	  photo.cc \
	  scripting_bridge.cc \
	  surface.cc

OBJECTS = $(CCFILES:%.cc=%.o)

NACL_SDK_ROOT = ../../..

CFLAGS = -Wall -Wno-long-long -pthread -DXP_UNIX -Werror
INCLUDES = -I$(NACL_SDK_ROOT) -I$(NACL_ROOT)
LDFLAGS = -lgoogle_nacl_imc \
          -lgoogle_nacl_npruntime \
          -lpthread \
          -lsrpc \
          -ljpeg \
          $(ARCH_FLAGS)
OPT_FLAGS = -O3 \
            -march=pentium4 \
            -mfpmath=sse \
            -msse3 \
            -funroll-loops \
            -fomit-frame-pointer


all: photo.nexe

# common.mk has rules to build .o files from .cc files.
-include ../../common.mk

photo.nexe: packages $(OBJECTS) carpe
	$(CPP) $^ $(LDFLAGS) -o $@

clean:
	-$(RM) $(OBJECTS) photo.nexe

# Build the required packages.
packages:
	cd $(NACL_SDK_ROOT)/packages/scripts/jpeg-6b; ./nacl-jpeg-6b.sh

# Download and patch the Carpe sliders.
carpe: default.css slider.js
	/bin/bash photo_tool.sh
