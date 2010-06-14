# Copyright (c) 2010 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that be
# found in the LICENSE file.
#
# Makefile for the MesaGL example.

NACL_SDK_ROOT = ../../..

CFLAGS = -Wall -Wno-long-long -pthread -DXP_UNIX -Werror -DGL_GLEXT_PROTOTYPES
INCLUDES = -I$(NACL_SDK_ROOT) -I$(NACL_ROOT)
# Note that the OpenGL libraries are NOT included.  We use Mesa for rendering.
LDFLAGS = -lgoogle_nacl_imc \
          -lgoogle_nacl_npruntime \
          -lpthread \
          -lsrpc \
          -lOSMesa
OPT_FLAGS = -O2

.SUFFIXES: .cc .o

ifeq ($(origin OS), undefined)
  ifeq ($(shell uname -s), Darwin)
    OS=Darwin
  else
    OS=$(shell uname -o)
  endif
endif

ifeq ($(OS), $(filter $(OS), Windows_NT Cygwin))
  PLATFORM = win
  TARGET = x86
endif
ifeq ($(OS), $(filter $(OS), Darwin MACOS))
  PLATFORM = mac
  TARGET = x86
endif

# Look for 'Linux' in the $(OS) string.  $(OS) is assumed to be a Linux
# variant if the result of $(findstring) is not empty.
ifneq (, $(findstring Linux, $(OS)))
  PLATFORM = linux
  TARGET = x86
endif

NACL_TOOLCHAIN_DIR = toolchain/$(PLATFORM)_$(TARGET)

CPP = $(NACL_SDK_ROOT)/$(NACL_TOOLCHAIN_DIR)/bin/nacl-g++

LIBMESA = $(NACL_SDK_ROOT)/$(NACL_TOOLCHAIN_DIR)/nacl/usr/lib/libOSMesa.a
PACKAGES_DIR = $(NACL_SDK_ROOT)/packages

all: $(LIBMESA) mesagl_x86_32.nexe mesagl_x86_64.nexe

mesagl_x86_32.nexe: mesagl.cc
	$(CPP) $(CFLAGS) -m32 $(INCLUDES) $(OPT_FLAGS) $< $(LDFLAGS) -o $@

mesagl_x86_64.nexe: mesagl.cc
	$(CPP) $(CFLAGS) -m64 $(INCLUDES) $(OPT_FLAGS) $< $(LDFLAGS) -o $@

$(LIBMESA):
	(cd $(PACKAGES_DIR)/scripts/Mesa-7.6; ./nacl-Mesa-7.6.sh)

clean:
	-rm mesagl_x86_32.nexe mesagl_x86_64.nexe
