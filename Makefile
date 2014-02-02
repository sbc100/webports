# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Makefile
#
# usage: 'make [package]'
#
# This makefile builds all of the Native Client ports listed below
# in $(ALL_PORTS). Each port has a dependency on its own sentinel
# file, which can be found at out/sentinels/*
#
# The makefile depends on the NACL_SDK_ROOT environment variable

OS_NAME := $(shell uname -s)

OS_SUBDIR := UNKNOWN
ifeq ($(OS_NAME), Darwin)
  OS_SUBDIR := mac
endif
ifeq ($(OS_NAME), Linux)
  OS_SUBDIR := linux
endif
ifneq (, $(filter CYGWIN%,$(OS_NAME)))
  OS_SUBDIR := win
endif

ifeq ($(OS_SUBDIR), UNKNOWN)
  $(error No support for the Operating System: $(OS_NAME))
endif

ifndef NACL_ARCH
ifeq ($(OS_NAME), Darwin)
   NACL_ARCH := i686
else
   NACL_ARCH := x86_64
endif
endif

ifndef NACL_SDK_ROOT
  $(error NACL_SDK_ROOT not set, see README.txt)
endif

ifeq ($(NACL_GLIBC), 1)
  ifeq ($(NACL_ARCH), arm)
    $(error NACL_GLIBC does not work with arm)
  endif
  ifeq ($(NACL_ARCH), pnacl)
    $(error NACL_GLIBC does not work with pnacl)
  endif
endif

ifeq ($(NACL_ARCH), arm)
  NACL_TOOLCHAIN_ROOT = $(NACL_SDK_ROOT)/toolchain/$(OS_SUBDIR)_arm_newlib
  NACL_LIBC = newlib
else
ifeq ($(NACL_GLIBC), 1)
  NACL_TOOLCHAIN_ROOT = $(NACL_SDK_ROOT)/toolchain/$(OS_SUBDIR)_x86_glibc
  NACL_LIBC = glibc
else
  NACL_TOOLCHAIN_ROOT = $(NACL_SDK_ROOT)/toolchain/$(OS_SUBDIR)_x86_newlib
  NACL_LIBC = newlib
endif
endif

NACL_OUT = out
NACL_DIRS_TO_REMOVE = $(NACL_OUT)/sentinels $(NACL_OUT)/stamp $(NACL_OUT)/repository

ifneq ($(NACL_ARCH),pnacl)
# The toolchain's 'usr' folder is reserved for naclports and we
# remove it completely on clean.  Except under 'pnacl' where the
# toolchain itself uses 'usr' so we can't currenctly cleanup
# fully.
NACLPORTS_PREFIX ?= $(NACL_TOOLCHAIN_ROOT)/$(NACL_ARCH)-nacl/usr
NACL_DIRS_TO_REMOVE += $(NACLPORTS_PREFIX)
else
NACLPORTS_PREFIX ?= $(NACL_TOOLCHAIN_ROOT)/usr
endif

ALL_PORTS = \
     ports/agg \
     ports/apr \
     ports/apr-util \
     ports/bash \
     ports/binutils \
     ports/bochs \
     ports/boost \
     ports/box2d \
     ports/bullet \
     ports/busybox \
     ports/bzip2 \
     ports/cairo \
     ports/cfitsio \
     ports/civetweb \
     ports/clapack \
     ports/coreutils \
     ports/curl \
     ports/devil \
     ports/dosbox \
     ports/dreadthread \
     ports/drod \
     ports/expat \
     ports/faac \
     ports/faad2 \
     ports/ffmpeg \
     ports/fftw \
     ports/flac \
     ports/fontconfig \
     ports/freealut \
     ports/freeimage \
     ports/freetype \
     ports/gc \
     ports/gcc \
     ports/gdb \
     ports/giflib \
     ports/git \
     ports/glib \
     ports/glibc-compat \
     ports/gmp \
     ports/gsl \
     ports/hdf5 \
     ports/imagemagick \
     ports/jpeg6b \
     ports/jpeg8d \
     ports/jsoncpp \
     ports/lame \
     ports/lcms \
     ports/leveldb \
     ports/libav \
     ports/libhangul \
     ports/libmikmod \
     ports/libmng \
     ports/libmodplug \
     ports/libogg \
     ports/libpng \
     ports/libsodium \
     ports/libtar \
     ports/libtheora \
     ports/libtomcrypt \
     ports/libtommath \
     ports/libvorbis \
     ports/libxml2 \
     ports/lua5.1 \
     ports/lua5.2 \
     ports/lua_ppapi \
     ports/make \
     ports/mesa \
     ports/mesagl \
     ports/metakit \
     ports/mongoose \
     ports/mpc \
     ports/mpfr \
     ports/mpg123 \
     ports/nacl-spawn \
     ports/nano \
     ports/ncurses \
     ports/netcat \
     ports/nethack \
     ports/openal-ogg \
     ports/openal-soft \
     ports/opencv \
     ports/openscenegraph \
     ports/openssh \
     ports/openssl \
     ports/pango \
     ports/pcre \
     ports/physfs \
     ports/pixman \
     ports/protobuf \
     ports/python \
     ports/python3 \
     ports/python3_ppapi \
     ports/python_ppapi \
     ports/readline \
     ports/regal \
     ports/ruby \
     ports/ruby_ppapi \
     ports/scummvm \
     ports/sdl \
     ports/sdl_image \
     ports/sdl_mixer \
     ports/sdl_net \
     ports/sdl_ttf \
     ports/snes9x \
     ports/speex \
     ports/sqlite \
     ports/subversion \
     ports/tar \
     ports/thttpd \
     ports/tiff \
     ports/tinyxml \
     ports/toybox \
     ports/vim \
     ports/webp \
     ports/x264 \
     ports/xaos \
     ports/yajl \
     ports/zeromq \
     ports/zlib

SENTINELS_DIR = $(NACL_OUT)/sentinels
SENT := $(SENTINELS_DIR)/$(NACL_ARCH)
ifneq ($(NACL_ARCH), pnacl)
  SENT := $(SENT)_$(NACL_LIBC)
endif
ifeq ($(NACL_DEBUG), 1)
  SENT := $(SENT)_debug
endif

all: $(ALL_PORTS)
# The subset of libraries that are shipped as part of the
# official NaCl SDK
SDK_LIBS = freealut freetype jpeg lua5.2 modplug ogg openal png theora tiff tinyxml
SDK_LIBS += vorbis webp xml2 zlib
sdklibs: $(SDK_LIBS)

package_list:
	@echo $(notdir $(ALL_PORTS))

sdklibs_list:
	@echo $(SDK_LIBS)

run:
	./httpd.py

.PHONY: all run clean sdklibs sdklibs_list reallyclean

clean:
	rm -rf $(NACL_DIRS_TO_REMOVE)

reallyclean: clean
	rm -rf $(NACL_OUT)

ifdef PRINT_DEPS
# Defining PRINT_DEPS means that we don't actually build anything
# but only echo the names of the packages that would have been built.
# In this case we use a dummy sentinal directory which will always
# be empty.
SENT = $(NACL_OUT)/dummy_location
$(ALL_PORTS): %: $(SENT)/%
else
$(ALL_PORTS): %: $(SENT)/%
endif

ifdef NACLPORTS_NO_ANNOTATE
  START_BUILD=echo "*** Building $(NACL_ARCH) $(notdir $*) ***"
else
  START_BUILD=echo "@@@BUILD_STEP $(NACL_ARCH) $(NACL_LIBC) $(notdir $*)@@@"
endif

ifdef CLEAN
.PHONY: $(ALL_PORTS:%=$(SENT)/%)
$(ALL_PORTS:%=$(SENT)/%):
	@rm $@
else
ifdef PRINT_DEPS
$(ALL_PORTS:%=$(SENT)/%): $(SENT)/%:
	@echo $(notdir $(subst $(SENT)/,,$@))
else
$(ALL_PORTS:%=$(SENT)/%): $(SENT)/%:
	@$(START_BUILD)
	python build_tools/naclports.py check -C $*
	if python build_tools/naclports.py enabled -C $*; then \
	cd $* && NACL_ARCH=$(NACL_ARCH) NACL_GLIBC=$(NACL_GLIBC) $(CURDIR)/build_tools/build_port.sh; fi
	mkdir -p $(@D)
	touch $@
endif
endif

$(shell mkdir -p ${NACL_OUT})
$(shell python build_tools/gen_deps.py > ${NACL_OUT}/gen.mk)
include ${NACL_OUT}/gen.mk

# Alias/shortcuts for certain ports (alphabetical)
faad: ports/faad2 ;
gif: ports/giflib ;
hangul: ports/libhangul ;
jpeg: ports/jpeg8d ;
lua: ports/lua5.2 ;
mikmod: ports/libmikmod ;
mng: ports/libmng ;
modplug: ports/libmodplug ;
ogg: ports/libogg ;
openal: ports/openal-soft ;
png: ports/libpng ;
sodium: ports/libsodium ;
tar: ports/libtar ;
theora: ports/libtheora ;
tomcrypt: ports/libtomcrypt ;
tommath: ports/libtommath ;
vorbis: ports/libvorbis ;
xml2: ports/libxml2 ;
