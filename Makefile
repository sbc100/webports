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

ifeq ($(V),1)
VERBOSE?=1
endif

# The subset of libraries that are shipped as part of the
# official NaCl SDK
SDK_LIBS = zlib tiff jpeg8d freealut freetype lua5.2 libmodplug libogg
SDK_LIBS += libpng libtheora libvorbis webp libxml2 tinyxml openal-soft

export VERBOSE
export NACL_ARCH
export NACL_GLIBC

all:
	build_tools/naclports.py --all build

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
	build_tools/naclports.py $(ARGS) build ports/$*

.PHONY: all run clean sdklibs sdklibs_list reallyclean
