# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Makefile
#
# usage: 'make [package]'
#
# This makefile builds all of the Native Client packages listed below
# in $(PACKAGES). Each package has a dependency on its own sentinel
# file, which can be found at naclports/src/out/sentinels/sentinel_file_*
#
# The makefile depends on the NACL_SDK_ROOT environment variable
#

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

BITSIZE := 32
ifeq ($(NACL_PACKAGES_BITSIZE), 64)
  BITSIZE := 64
endif


NACL_TOOLCHAIN_ROOT = $(NACL_SDK_ROOT)/toolchain/$(OS_SUBDIR)_x86

NACL_OUT = ../out
NACL_DIRS_BASE = $(NACL_OUT)/tarballs \
                 $(NACL_OUT)/repository \
                 $(NACL_OUT)/repository64 \
                 $(NACL_OUT)/publish \
                 $(NACL_OUT)/publish64

NACL_SDK_USR32 = $(NACL_TOOLCHAIN_ROOT)/nacl/usr
NACL_SDK_USR64 = $(NACL_TOOLCHAIN_ROOT)/nacl64/usr

NACL_DIRS_TO_REMOVE = $(NACL_OUT) \
		      $(NACL_SDK_USR32) \
		      $(NACL_SDK_USR64)

NACL_DIRS_TO_MAKE = $(NACL_DIRS_BASE) \
		    $(NACL_SDK_USR32)/include \
		    $(NACL_SDK_USR64)/include \
		    $(NACL_SDK_USR32)/lib \
		    $(NACL_SDK_USR64)/lib

PACKAGES = nacl-mounts \
           SDL-1.2.14 \
	   gc6.8 \
	   fftw-3.2.2 \
	   libtommath-0.41 \
	   libtomcrypt-1.17 \
	   zlib-1.2.3 \
	   jpeg-6b \
	   libpng-1.2.40 \
	   tiff-3.9.1 \
	   FreeImage-3.14.1 \
	   libogg-1.1.4 \
	   libvorbis-1.2.3 \
	   lame-398-2 \
	   faad2-2.7 \
	   faac-1.28 \
	   libtheora-1.1.1 \
	   flac-1.2.1 \
	   speex-1.2rc1 \
           x264-snapshot-20091023-2245 \
	   lua-5.1.4 \
	   tinyxml \
	   expat-2.0.1 \
	   pixman-0.16.2 \
	   gsl-1.9 \
	   freetype-2.1.10 \
	   fontconfig-2.7.3 \
	   agg-2.5 \
	   cairo-1.8.8 \
	   ImageMagick-6.5.4-10 \
	   ffmpeg-0.5 \
	   Mesa-7.6 \
	   libmodplug-0.8.7 \
	   memory_filesys \
	   OpenSceneGraph-2.9.7 \
           nethack-3.4.3 \
           cfitsio \
           boost_1_43_0 \
           protobuf-2.3.0

SENTINELS_DIR = $(NACL_OUT)/sentinels
SENT = $(SENTINELS_DIR)/sentinel_file_$(BITSIZE)_

.PHONY: all clean

all: $(PACKAGES)

clean:
	rm -rf $(NACL_DIRS_TO_REMOVE)

$(NACL_DIRS_TO_MAKE):
	mkdir -p $@

$(PACKAGES): %: $(NACL_DIRS_TO_MAKE) $(SENT)%

$(PACKAGES:%=$(SENT)%): $(SENT)%:
	cd libraries/$* && ./nacl-$*.sh
	mkdir -p $(@D)
	touch $@

# packages with dependencies
$(SENT)libvorbis-1.2.3: ogg
$(SENT)libtheora-1.1.1: ogg
$(SENT)flac-1.2.1: ogg
$(SENT)speex-1.2rc1: ogg
$(SENT)fontconfig-2.7.3: expat freetype
$(SENT)libpng-1.2.40: zlib
$(SENT)agg-2.5: freetype
$(SENT)cairo-1.8.8: pixman fontconfig png
$(SENT)ffmpeg-0.5: lame vorbis theora
$(SENT)nethack-3.4.3: memory_filesys

# shortcuts
sdl: SDL-1.2.14 ;
gc: gc6.8 ;
fftw: fftw-3.2.2 ;
tommath: libtommath-0.41 ;
tomcrypt: libtomcrypt-1.17 ;
zlib: zlib-1.2.3 ;
jpeg: jpeg-6b ;
png: libpng-1.2.40 ;
tiff: tiff-3.9.1 ;
freeimage: FreeImage-3.14.1 ;
ogg: libogg-1.1.4 ;
vorbis: libvorbis-1.2.3 ;
lame: lame-398-2 ;
faad: faad2-2.7 ;
faac: faac-1.28 ;
theora: libtheora-1.1.1 ;
flac: flac-1.2.1 ;
speex: speex-1.2rc1 ;
x264: x264-snapshot-20091023-2245 ;
lua: lua-5.1.4 ;
expat: expat-2.0.1 ;
pixman: pixman-0.16.2 ;
gsl: gsl-1.9 ;
freetype: freetype-2.1.10 ;
fontconfig: fontconfig-2.7.3 ;
agg: agg-2.5 ;
cairo: cairo-1.8.8 ;
imagemagick: ImageMagick-6.5.4-10 ;
ffmpeg: ffmpeg-0.5 ;
mesa: Mesa-7.6 ;
modplug: libmodplug-0.8.7 ;
openscenegraph: OpenSceneGraph-2.9.7 ;
nethack: nethack-3.4.3 ;
boost: boost_1_43_0 ;
protobuf: protobuf-2.3.0 ;