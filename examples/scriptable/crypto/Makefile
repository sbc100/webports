# Copyright 2010, The Native Client SDK Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can
# be found in the LICENSE file.

# Makefile for the Crypto example.

.PHONY:  all clean

NACLPORTS_ROOT = ../../..

CCFILES = aes_codec.cc \
          base64.cc \
	  loader.cc \
	  npp_gate.cc \
	  scriptable.cc \
          scriptable_aes_codec.cc \
	  scripting_bridge.cc
          

OBJECTS_X86_32 = $(CCFILES:%.cc=%_x86_32.o)
OBJECTS_X86_64 = $(CCFILES:%.cc=%_x86_64.o)

CFLAGS = -Wall -Wno-long-long -pthread -DXP_UNIX -Werror
INCLUDES = -I$(NACL_SDK_ROOT) -I$(NACLPORTS_ROOT)

LDFLAGS = $(ARCH_FLAGS) \
          -lgoogle_nacl_npruntime \
          -lpthread \
          -lsrpc \
          -lgoogle_nacl_imc \
          -ltomcrypt

OPT_FLAGS = -O2

# The crypto executable depends on TomCrypt library

TOMCRYPT_64 = \
  $(NACL_SDK_ROOT)/$(NACL_TOOLCHAIN_DIR)/nacl64/usr/include/tomcrypt.h

TOMCRYPT_32 = \
  $(NACL_SDK_ROOT)/$(NACL_TOOLCHAIN_DIR)/nacl/usr/include/tomcrypt.h

PACKAGES = $(TOMCRYPT_32) $(TOMCRYPT_64)

all: all_crypto

# common.mk has rules to build .o files from .cc files.
-include $(NACLPORTS_ROOT)/common_build_scripts/nacl_build.mk

all_crypto: check_variables $(PACKAGES) crypto_x86_32.nexe crypto_x86_64.nexe

crypto_x86_32.nexe: $(OBJECTS_X86_32)
	$(CPP) $^ $(LDFLAGS) -m32 -o $@

crypto_x86_64.nexe: $(OBJECTS_X86_64)
	$(CPP) $^ $(LDFLAGS) -m64 -o $@

clean:
	-$(RM) $(OBJECTS_X86_32) $(OBJECTS_X86_64) \
	    crypto_x86_32.nexe crypto_x86_64.nexe

# Build the required packages.
$(TOMCRYPT_32):
	(cd $(NACLPORTS_ROOT)/packages/scripts/libtomcrypt-1.17; \
	export NACL_PACKAGES_BITSIZE=32; \
	./nacl-libtomcrypt-1.17.sh)

$(TOMCRYPT_64):
	(cd $(NACLPORTS_ROOT)/packages/scripts/libtomcrypt-1.17; \
	export NACL_PACKAGES_BITSIZE=64; \
	./nacl-libtomcrypt-1.17.sh)

