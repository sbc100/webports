# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Makefile
#
# usage: 'make [package]'
#
# This makefile can by used to perform common actions such as building
# all ports, building a give port, running a webserver to test the ports.
# Each port has a dependency on its own sentinel file, which can be found
# at out/sentinels/*

SDK_LIBS = zlib tiff jpeg8d libpng freetype lua5.2 libmodplug libogg
SDK_LIBS += libtheora libvorbis libwebp libxml2 tinyxml openal-soft freealut

ifeq ($(V),1)
VERBOSE?=1
endif

ifeq ($(VERBOSE),1)
BUILD_FLAGS+=-v
endif

ifeq ($(FORCE),1)
BUILD_FLAGS+=-f
endif

export NACL_ARCH
export TOOLCHAIN
export NACL_GLIBC

all:
	build_tools/naclports.py --all install $(BUILD_FLAGS)

sdklibs: $(SDK_LIBS)

sdklibs_list:
	@echo $(SDK_LIBS)

run:
	./httpd.py

clean:
	build_tools/naclports.py --all clean

reallyclean: clean
	rm -rf $(NACL_OUT)

%:
	build_tools/naclports.py install $* $(BUILD_FLAGS)

.PHONY: all run clean sdklibs sdklibs_list reallyclean
