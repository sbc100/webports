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

SDK_LIBS = zlib tiff jpeg8d libpng freetype lua5.2 libogg
SDK_LIBS += libtheora libvorbis libwebp libxml2 tinyxml openal-soft freealut

COVERAGE = python third_party/coverage
COVERAGE_ARGS = --fail-under=56
COVERAGE_VER := $(shell $(COVERAGE) --version 2>/dev/null)

ifeq ($(V),1)
VERBOSE ?= 1
endif

ifeq ($(F),1)
FORCE ?= 1
endif

ifeq ($(V),2)
VERBOSE ?= 1
VERBOSE_BUILD ?= 1
endif

ifeq ($(VERBOSE),1)
BUILD_FLAGS += -v
endif

ifeq ($(VERBOSE_BUILD),1)
BUILD_FLAGS += --verbose-build
endif

ifeq ($(FORCE),1)
BUILD_FLAGS += -f
endif

ifeq ($(FROM_SOURCE),1)
BUILD_FLAGS += --from-source
endif

export NACL_ARCH
export TOOLCHAIN
export NACL_GLIBC

all:
	bin/naclports --all install $(BUILD_FLAGS)

sdklibs: $(SDK_LIBS)

sdklibs_list:
	@echo $(SDK_LIBS)

run:
	./build_tools/httpd.py

clean:
	bin/naclports --all clean

reallyclean: clean
	rm -rf $(NACL_OUT)

check: test

test:
	build_tools/build_tools_test.py
	$(COVERAGE) run --include=lib/naclports/* lib/naclports_test.py
	$(COVERAGE) report $(COVERAGE_ARGS)
	@rm -rf out/coverage_html
	$(COVERAGE) html

%:
	bin/naclports install $* $(BUILD_FLAGS)

.PHONY: all run clean sdklibs sdklibs_list reallyclean check test
